//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { LSSVMPair } from "./sudoHelpers/LSSVMPair.sol";
import { LSSVMPairETH } from "./sudoHelpers/LSSVMPairETH.sol";
import { LSSVMPairEnumerableETH } from "./sudoHelpers/LSSVMPairEnumerableETH.sol";
import { LSSVMPairFactory } from "./sudoHelpers/LSSVMPairFactory.sol";
import { OwnableWithTransferCallback } from "./sudoHelpers/OwnableWithTransferCallback.sol";
import { Vault } from "./abacusHelpers/Vault.sol";
import { Lend } from "./abacusHelpers/Lend.sol";

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

    // address public admin = recovery address that we decide to use
    address public admin;

    uint256 public totalSupply;
    uint256 public testVar;

    mapping(address => Pairing) public pairing;
    mapping(uint256 => address) public lendingLocation;
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

    event CallbackTriggered(address _caller);

    constructor(
        address _admin,
        address _factoryAddress,
        address _collection,
        uint256 _totalSupply
    ) ERC721(ERC721(_collection).name(), ERC721(_collection).symbol()) {
        admin = _admin;
        sudoFactory = LSSVMPairFactory(payable(_factoryAddress));
        collection = ERC721(_collection);
        totalSupply = _totalSupply;
    }

    receive() external payable {}
    fallback() external payable {}

    function initiatePool(address _sudoPool) external {
        require(msg.sender == LSSVMPair(_sudoPool).owner());
        require(pairing[_sudoPool].active == false);
        require(sudoFactory.isPair(_sudoPool, LSSVMPair(_sudoPool).pairVariant()));
        pairing[_sudoPool].active = true;
        pairing[_sudoPool].owner = msg.sender;
    }

    function borrow(
        address _lendingContract,
        bytes32[] calldata _merkleProof, 
        address _spotPool,
        address _sudoPool,
        uint256 _lpTokenId,
        uint256 _amount
    ) external poolOwnedByContract(_sudoPool) {
        // Create reflection NFT
        require(_lpTokenId < totalSupply, "Improper token id input");
        require(!idExistence[_lpTokenId], "LpIdAlreadyTaken");
        if(!_exists(_lpTokenId)) {
            _mint(address(this), _lpTokenId);
            pairing[_sudoPool].amountActive++;
            nftLocation[_lpTokenId] = _sudoPool;
            lendingLocation[_lpTokenId] = _lendingContract;
        } else {
            require(borrower[_lpTokenId] == msg.sender, "No soup for you!");
        }
        // amount must be 10% less than listing price
        uint256 currentPrice;
        uint256 currentlyBorrowed;
        if(pairing[_sudoPool].price == 0) {
            (,,, currentPrice,) = LSSVMPair(_sudoPool).getBuyNFTQuote(1);
            require(currentPrice < 2**128-1, "Price too high!");
            pairing[_sudoPool].price = uint128(currentPrice);
            pairing[_sudoPool].active = true;
        } else {
            currentPrice = pairing[_sudoPool].price;
            (,,,, currentlyBorrowed,) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
        }
        require(
            currentPrice >= 110 * (_amount + currentlyBorrowed) / 100
            , "Listing price must be 10% greater than borrow amount"
        );
        address currency = address(Vault(_spotPool).token());
        require(
            collection.balanceOf(_sudoPool) >= pairing[_sudoPool].amountActive
            , "Not enough NFTs in the sudo pool to allow this!"
        );
        // Execute borrow against LP position
        _approve(_lendingContract, _lpTokenId);
        Lend(payable(_lendingContract)).borrow(
            _merkleProof,
            _spotPool,
            address(this),
            _lpTokenId,
            _amount
        );
        require(ERC20(currency).transfer(msg.sender, _amount), "Transfer failed");
    }

    function payInterest(
        address _lendingContract,
        uint256[] calldata _epoch,
        uint256 _lpTokenId
    ) external {
        // Basic pay interest transitory
        // Calculate interest cost 
        uint256 amount = Lend(payable(_lendingContract)).getInterestPayment(_epoch, address(this), _lpTokenId);
        // Approve lending contract to take that amount
        (,address spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
        address currency = address(Vault(spotPool).token());
        ERC20(currency).transferFrom(msg.sender, address(this), amount);
        ERC20(currency).approve(_lendingContract, amount);
        // Call pay interest 
        Lend(payable(_lendingContract)).payInterest(_epoch, address(this), _lpTokenId);
    }

    function repay(
        address _lendingContract,
        address _sudoPool,
        uint256 _lpTokenId,
        uint256 _amount
    ) external poolOwnedByContract(_sudoPool) {
        require(msg.sender == pairing[_sudoPool].owner, "Not pool owner!");
        // Basic repay transitory
        // Approve lending contract to take that amount
        (,address spotPool,,,,uint256 interestEpoch) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
        address currency = address(Vault(spotPool).token());
        Vault vault = Vault(spotPool);
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        uint256 finalInterestPayment;
        if(poolEpoch == interestEpoch) {
            finalInterestPayment = vault.interestRate() * vault.getPayoutPerReservation(poolEpoch) / 10_000 
                        * vault.epochLength() / (52 weeks);
        } else {
            require(poolEpoch + 1 == interestEpoch, "Must pay outstanding interest");
        }
        ERC20(currency).transferFrom(msg.sender, address(this), _amount + finalInterestPayment);
        ERC20(currency).approve(_lendingContract, _amount + finalInterestPayment);
        // Call repay
        Lend(payable(_lendingContract)).repay(address(this), _lpTokenId, _amount);
        (, spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
        if(spotPool == address(0)) {
            pairing[_sudoPool].amountActive--;
            _burn(_lpTokenId);
        }
        if(pairing[_sudoPool].amountActive == 0) {
            delete pairing[_sudoPool].price;
        }
    }

    function liquidateLp(
        address _lendingContract,
        uint256 _lpTokenId,
        uint256[] calldata _epochs
    ) external {
        (, address spotPool,,,uint256 loanAmount,) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
        Vault vault = Vault(payable(spotPool));
        uint256 futurePayout = vault.getPayoutPerReservation(
            (block.timestamp - vault.startTime() + vault.epochLength() / 2) / vault.epochLength()
        );
        uint256 outstandingInterest = Lend(payable(_lendingContract)).getInterestPayment(
            _epochs[0:_epochs.length - 1], 
            address(this), 
            _lpTokenId
        );
        // contract checks borrow position on lending contract 
            // if within LP liquidation window + base liquidation window, can liquidate
            // else revert
        // if liquidation goes through
            // liquidator sends borrow currency to contract
            // use currency to pay down debt + interest
            // liquidator gains control of the NFT or underlying spot price value 
        if(loanAmount > futurePayout) {

            vault.token().transferFrom(
                msg.sender,
                address(this),
                loanAmount + outstandingInterest
            );
            vault.token().approve(_lendingContract, outstandingInterest);
            // Call pay interest 
            Lend(payable(_lendingContract)).payInterest(
                _epochs[0:_epochs.length - 1],
                address(this),
                _lpTokenId
            );
            outstandingInterest = Lend(payable(_lendingContract)).getInterestPayment(
                _epochs[_epochs.length - 1:],
                address(this),
                _lpTokenId
            );
            vault.token().approve(_lendingContract, loanAmount + outstandingInterest);
            // Call repay
            Lend(payable(_lendingContract)).repay(
                address(this),
                _lpTokenId,
                loanAmount
            );
            _transfer(address(this), msg.sender, _lpTokenId);
        } else {
            revert("Liquidation failed");
        }
    }

    function exchangeLPforNFT(uint256[] calldata tokenId, uint256 _lpTokenId) external {
        address _sudoPool = nftLocation[_lpTokenId];
        address _lendingContract = lendingLocation[_lpTokenId];
        address _currentOwnerOfLP = ownerOf(_lpTokenId);
        require(ownerOf(_lpTokenId) != _lendingContract, "Can't call this if the owner is the lending contract!");
        require(collection.ownerOf(tokenId[0]) == _sudoPool, "Chosen NFT not in sudo pool");
        pairing[_sudoPool].amountActive--;
        _burn(_lpTokenId);
        if(pairing[_sudoPool].amountActive == 0) {
            delete pairing[_sudoPool].price;
        }
        LSSVMPair(_sudoPool).withdrawERC721(collection, tokenId);
        collection.transferFrom(
            address(this), 
            _currentOwnerOfLP, 
            tokenId[0]
        );
    }

    function exchangeLPforETH(uint256 _lpTokenId) external payable {
        address _sudoPool = nftLocation[_lpTokenId];
        address _lendingContract = lendingLocation[_lpTokenId];
        address _currentOwnerOfLP = ownerOf(_lpTokenId);
        require(ownerOf(_lpTokenId) != _lendingContract, "Can't call this if the owner is the lending contract!");
        require(collection.balanceOf(_sudoPool) == 0, "Can only claim ETH if there are no NFTs in the pool");
        uint256 ETHpayout = pairing[_sudoPool].price;
        pairing[_sudoPool].amountActive--;
        _burn(_lpTokenId);
        if(pairing[_sudoPool].amountActive == 0) {
            delete pairing[_sudoPool].price;
        }
        LSSVMPairETH(payable(_sudoPool)).withdrawETH(ETHpayout);
        payable(_currentOwnerOfLP).transfer(ETHpayout);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function callTransferOwnership(address _sudoPool) external poolActive(_sudoPool) {
        address owner = pairing[_sudoPool].owner;
        delete pairing[_sudoPool];
        if(
            owner == address(0)
            && LSSVMPair(_sudoPool).owner() == address(this)
        ) {
            require(msg.sender == admin);
        } else {
            require(msg.sender == owner);    
        }
        LSSVMPair(_sudoPool).transferOwnership(owner);
    }
}