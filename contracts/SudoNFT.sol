//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { LSSVMPair } from "./sudoHelpers/LSSVMPair.sol";
import { LSSVMPairETH } from "./sudoHelpers/LSSVMPairETH.sol";
import { LSSVMPairEnumerableETH } from "./sudoHelpers/LSSVMPairEnumerableETH.sol";
import { LSSVMPairFactory } from "./sudoHelpers/LSSVMPairFactory.sol";
import { OwnableWithTransferCallback } from "./sudoHelpers/OwnableWithTransferCallback.sol";
import { Vault } from "./abacusHelpers/Vault.sol";
import { Lend } from "./abacusHelpers/Lend.sol";
import { AbacusController } from "./abacusHelpers/AbacusController.sol";

import { IVault } from "./abacusInterfaces/IVault.sol";
import { ILend } from "./abacusInterfaces/ILend.sol";
import { ILSSVMPairFactory } from "./sudoInterfaces/ILSSVMPairFactory.sol";
import { ILSSVMPairFactoryLike } from "./sudoInterfaces/ILSSVMPairFactoryLike.sol";
import { ICurve } from "./sudoInterfaces/ICurve.sol";
import { IOwnershipTransferCallback } from "./sudoInterfaces/IOwnershipTransferCallback.sol";

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SudoNft is ERC721 {

    ERC721 public collection;
    LSSVMPairFactory public sudoFactory;
    AbacusController public controller;

    // address public admin = recovery address that we decide to use
    address public admin;

    uint256 public totalSupply;
    uint256 public testVar;

    mapping(address => Pairing) public pairing;
    mapping(uint256 => address) public nftLocation;
    mapping(uint256 => address) public borrower;
    mapping(uint256 => bool) public idExistence;

    struct Pairing {
        bool active;
        address owner;
        uint96 amountActive;
        uint128 price;
    }

    modifier poolOwnedByContract(address _pool) {
        require(
            pairing[_pool].active 
            && LSSVMPair(_pool).owner() == address(this)
            , "Pool not owned by contract"
        );
        _;
    }

    modifier ownerCaller(address _pool) {
        require(
            msg.sender == pairing[_pool].owner
            , "Improper caller (ownerCaller)"
        );
        _;
    }

    modifier poolActive(address _pool) {
        require(
            pairing[_pool].amountActive == 0
            , "Pool is currently active"
        );
        _;
    }

    event TransferInitiated(address _from, address[] _pool);
    event OwnershipReceived(address _pool);
    event OwnershipTransferred(address _from, address _pool);
    event Borrowed(address _from, address _spotPool, address _sudoPool, uint256[] _tokenIds, uint256[] _amounts);
    event InterestPaid(address _from, uint256[] _tokenIds);
    event Repaid(address _from, uint256[] _tokenIds, uint256[] _amounts);
    event Liquidated(address _from, uint256[] _tokenIds);
    event LPForNFT(address _from, uint256[] _tokenIds);
    event LPForETH(address _from, uint256[] _tokenIds);

    constructor(
        address _admin,
        address _abacusController,
        address _factoryAddress,
        address _collection,
        uint256 _totalSupply
    ) ERC721(ERC721(_collection).name(), ERC721(_collection).symbol()) {
        admin = _admin;
        controller = AbacusController(_abacusController);
        sudoFactory = LSSVMPairFactory(payable(_factoryAddress));
        collection = ERC721(_collection);
        totalSupply = _totalSupply;
    }

    receive() external payable {}
    fallback() external payable {}

    function initiatePool(address[] calldata _sudoPools) external {
        for (uint256 i = 0; i < _sudoPools.length; i++) {
            address _sudoPool = _sudoPools[i];
            require(
                msg.sender == LSSVMPair(_sudoPool).owner()
                , "Not pair owner"
            );
            require(
                LSSVMPair(_sudoPool).getAllHeldIds().length > 0
                , "No NFTs in the pool"
            );
            require(
                LSSVMPair(_sudoPool).nft() == collection
                , "Incompatible NFT collection"
            );
            require(
                pairing[_sudoPool].active == false
                , "Already initiated"
            );
            require(
                sudoFactory.isPair(_sudoPool, LSSVMPair(_sudoPool).pairVariant())
                , "Not a real pair"
            );
            pairing[_sudoPool].active = true;
            pairing[_sudoPool].owner = msg.sender;
        }
        emit TransferInitiated(msg.sender, _sudoPools);
    }

    function borrow(
        address _spotPool,
        address _sudoPool,
        bytes32[][] calldata _merkleProofs,
        address[] calldata _addresses,
        uint256[] calldata _lpTokenIds,
        uint256[] calldata _amounts
    ) external poolOwnedByContract(_sudoPool) ownerCaller(_sudoPool) {
        require(controller.accreditedAddresses(_spotPool), "Not an accredited pool");
        uint256 currentPrice = _findCurrentPrice(_sudoPool);
        emit Borrowed(msg.sender, _spotPool, _sudoPool, _lpTokenIds, _amounts);
        (uint256 totalBorrowAmount, ) = _checkLPIds(
            msg.sender,
            _sudoPool,
            currentPrice,
            _lpTokenIds,
            _amounts
        );
        _setApprovalForAll(address(this), controller.lender(), true);
        Lend(payable(controller.lender())).borrow(
            _spotPool,
            _merkleProofs,
            _addresses,
            _lpTokenIds,
            _amounts
        );
        require(Vault(_spotPool).token().transfer(msg.sender, totalBorrowAmount), "Transfer failed");
    }

    function payInterest(
        address _spotPool,
        address[] calldata _addresses,
        uint256[] calldata _lpTokenIds
    ) external {
        Lend lend = Lend(payable(controller.lender()));
        require(controller.accreditedAddresses(_spotPool), "Not an accredited pool");
        uint256 amount = lend.getInterestPayment(_spotPool, _addresses, _lpTokenIds);
        Vault(_spotPool).token().transferFrom(msg.sender, address(this), amount);
        Vault(_spotPool).token().approve(address(lend), amount);
        lend.payInterest(_spotPool, _addresses, _lpTokenIds);
        emit InterestPaid(msg.sender, _lpTokenIds);
    }

    function repay(
        address _spotPool,
        address _sudoPool,
        address[] calldata _addresses,
        uint256[] calldata _lpTokenIds,
        uint256[] calldata _amounts
    ) external poolOwnedByContract(_sudoPool) ownerCaller(_sudoPool) {
        require(controller.accreditedAddresses(_spotPool), "Not an accredited pool");
        Lend lend = Lend(payable(controller.lender()));
        Vault vault = Vault(_spotPool);
        uint256 loansClosed;
        uint256 totalPaymentAmount;
        for(uint256 i = 0; i < _addresses.length; i++) {
            uint256 _lpTokenId = _lpTokenIds[i];
            uint256 _amount = _amounts[i];
            (,,,,,uint256 interestEpoch) = lend.loans(address(this), _lpTokenId);
            uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
            uint256 finalInterestPayment;
            if(poolEpoch == interestEpoch) {
                finalInterestPayment = vault.interestRate() * vault.getPayoutPerReservation(poolEpoch) / 10_000 
                            * vault.epochLength() / (52 weeks);
            } else {
                require(poolEpoch + 1 == interestEpoch, "Must pay outstanding interest");
            }
            totalPaymentAmount += _amount + finalInterestPayment;
        }
        Vault(_spotPool).token().transferFrom(msg.sender, address(this), totalPaymentAmount);
        Vault(_spotPool).token().approve(address(lend), totalPaymentAmount);
        lend.repay(_spotPool, _addresses, _lpTokenIds, _amounts);
        for(uint256 i = 0; i < _addresses.length; i++) {
            uint256 _lpTokenId = _lpTokenIds[i];
            if(lend.getLoanAmount(address(this), _lpTokenId) == 0) {
                loansClosed++;
                _burn(_lpTokenId);
            }
        }
        pairing[_sudoPool].amountActive -= uint96(loansClosed);
        if(pairing[_sudoPool].amountActive == 0) {
            delete pairing[_sudoPool].price;
        }
        emit Repaid(msg.sender, _lpTokenIds, _amounts);
    }

    function liquidateLp(
        address _spotPool,
        address[] calldata _addresses,
        uint256[] calldata _lpTokenIds,
        uint256[] calldata _amounts
    ) external {
        Lend lend = Lend(payable(controller.lender()));
        Vault vault = Vault(payable(_spotPool));
        uint256 futurePayout = vault.getPayoutPerReservation(
            (block.timestamp - vault.startTime() + vault.epochLength() / 2) / vault.epochLength()
        );
        uint256 outstandingInterest = lend.getInterestPayment(
            _spotPool,
            _addresses, 
            _lpTokenIds
        );
        vault.token().transferFrom(
            msg.sender,
            address(this),
            outstandingInterest
        );
        vault.token().approve(address(lend), outstandingInterest);
        lend.payInterest(_spotPool, _addresses, _lpTokenIds);
        uint256 totalRepaymentAmount = lend.getRepaymentAmount(
            _spotPool,
            _addresses,
            _lpTokenIds,
            _amounts
        );
        vault.token().transferFrom(
            msg.sender,
            address(this),
            totalRepaymentAmount
        );
        for(uint256 i = 0; i < _addresses.length; i++) {
            require(
                lend.getLoanAmount(address(this), _lpTokenIds[i]) > futurePayout
                , "Liquidation failed"
            );
        }
        vault.token().approve(address(lend), totalRepaymentAmount);
        lend.repay(_spotPool, _addresses, _lpTokenIds, _amounts);
        for(uint256 i = 0; i < _addresses.length; i++) {
            _transfer(address(this), msg.sender, _lpTokenIds[i]);
        }
        emit Liquidated(msg.sender, _lpTokenIds);
    }

    function exchangeLPforNFT(address _sudoPool, uint256[] calldata _tokenIds, uint256[] calldata _lpTokenIds) external {
        for(uint256 i = 0; i < _lpTokenIds.length; i++) {
            require(
                collection.ownerOf(_tokenIds[i]) == _sudoPool
                , "Chosen NFT not in sudo pool"
            );
        }
        LSSVMPair(_sudoPool).withdrawERC721(collection, _tokenIds);
        for(uint256 i = 0; i < _lpTokenIds.length; i++) {
            uint256 _lpTokenId = _lpTokenIds[i];
            uint256 _tokenId = _tokenIds[i];
            require(
                nftLocation[_lpTokenId] == _sudoPool
                , "LP token not connected to sudo pool"
            );
            address _currentOwnerOfLP = ownerOf(_lpTokenId);
            require(
                ownerOf(_lpTokenId) != controller.lender()
                , "Can't call this if the owner is the lending contract!"
            );
            _burn(_lpTokenId);
            if(pairing[_sudoPool].amountActive == 0) {
                delete pairing[_sudoPool].price;
            }
            collection.transferFrom(
                address(this), 
                _currentOwnerOfLP, 
                _tokenId
            );
        }
        pairing[_sudoPool].amountActive -= uint96(_lpTokenIds.length);
        emit LPForNFT(msg.sender, _lpTokenIds);
    }

    function exchangeLPforETH(address _sudoPool, address _owner, uint256[] calldata _lpTokenIds) external payable {
        uint256 totalWithdrawalAmount;
        for(uint256 i = 0; i < _lpTokenIds.length; i++) {
            uint256 _lpTokenId = _lpTokenIds[i];
            require(
                nftLocation[_lpTokenId] == _sudoPool
                , "LP token not connected to sudo pool"
            );
            require(
                ownerOf(_lpTokenId) == _owner
                , "Incorrect owner input!"
            );
            require(
                ownerOf(_lpTokenId) != controller.lender()
                , "Can't call this if the owner is the lending contract!"
            );
            require(
                collection.balanceOf(_sudoPool) == 0
                , "Can only claim ETH if there are no NFTs in the pool"
            );
            totalWithdrawalAmount += pairing[_sudoPool].price - 5 * pairing[_sudoPool].price / 1000;
            _burn(_lpTokenId);
        }
        pairing[_sudoPool].amountActive -= uint96(_lpTokenIds.length);
        if(pairing[_sudoPool].amountActive == 0) {
            delete pairing[_sudoPool].price;
        }
        LSSVMPairETH(payable(_sudoPool)).withdrawETH(totalWithdrawalAmount);
        payable(_owner).transfer(totalWithdrawalAmount);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onOwnershipTransfer(address _pool) external {
        emit OwnershipReceived(msg.sender);
    }

    function callTransferOwnership(address _sudoPool) external poolActive(_sudoPool) {
        address owner = pairing[_sudoPool].owner;
        delete pairing[_sudoPool];
        if(
            owner == address(0)
            && LSSVMPair(_sudoPool).owner() == address(this)
        ) {
            require(
                msg.sender == admin
                , "Not admin"
            );
        } else {
            require(
                msg.sender == owner
                , "Not owner"    
            );
        }
        LSSVMPair(_sudoPool).transferOwnership(owner);
        emit OwnershipTransferred(owner, _sudoPool);
    }

    // ============ Internal Functions ============ //
    function _findCurrentPrice(
        address _sudoPool
    ) internal returns(uint256 currentPrice) {
        Pairing storage _pairing = pairing[_sudoPool];
        if(_pairing.price == 0) {
            (,,, currentPrice,) = LSSVMPair(_sudoPool).getBuyNFTQuote(1);
            _pairing.price = uint128(currentPrice);
            _pairing.active = true;
        } else {
            currentPrice = _pairing.price;
        }
        require(
            currentPrice < 2**128-1
            , "Price too high!"
        );
    }

    function _checkLPIds(
        address _user,
        address _sudoPool,
        uint256 _currentPrice,
        uint256[] calldata _lpTokenIds,
        uint256[] calldata _amounts
    ) internal returns(uint256 totalBorrowAmount, uint256 newLoans) {
        Pairing storage _pairing = pairing[_sudoPool];
        for(uint256 i = 0; i < _lpTokenIds.length; i++) {
            uint256 _lpTokenId = _lpTokenIds[i];
            uint256 _amount = _amounts[i];
            require(
                _lpTokenId < totalSupply
                , "Improper token id input"
            );
            if(!_exists(_lpTokenId)) {
                _mint(address(this), _lpTokenId);
                newLoans++;
                nftLocation[_lpTokenId] = _sudoPool;
            } else {
                require(
                    borrower[_lpTokenId] == _user
                    , "No soup for you!"
                );
            }
            require(
                _currentPrice >= 110 * (
                    _amount + Lend(payable(controller.lender())).getLoanAmount(address(this), _lpTokenId)
                ) / 100
                , "Listing price must be 10% greater than borrow amount"
            );
            totalBorrowAmount += _amount;
        }
        _pairing.amountActive += uint96(newLoans);
        require(
            collection.balanceOf(_sudoPool) >= _pairing.amountActive
            , "Not enough NFTs in the sudo pool to allow this!"
        );
    }
}