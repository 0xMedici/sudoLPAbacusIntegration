//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { LSSVMPair } from "./sudoHelpers/LSSVMPair.sol";
import { LSSVMPairETH } from "./sudoHelpers/LSSVMPairETH.sol";
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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SudoNft is ERC721, OwnableWithTransferCallback {

    ERC721 public collection;
    ILSSVMPairFactory public sudoFactory;
    uint256 public totalSupply;

    mapping(address => Pairing) public pairing;
    mapping(uint256 => bool) public idExistence;

    struct Pairing {
        bool active;
        address owner;
        uint96 amountActive;
        uint128 price;
    }

    modifier poolOwnedByContract(address _pool) {
        require(pairing[_pool].active);
        _;
    }

    modifier ownerCaller(address _pool) {
        require(msg.sender == pairing[_pool].owner);
        _;
    }

    modifier poolActive(address _pool) {
        require(pairing[_pool].amountActive == 0);
        _;
    }

    constructor(
        address _factoryAddress,
        address _collection,
        uint256 _totalSupply
    ) ERC721(ERC721(_collection).name(), ERC721(_collection).symbol()) {
        sudoFactory = ILSSVMPairFactory(_factoryAddress);
        collection = ERC721(_collection);
        totalSupply = _totalSupply;
    }

    function depositNFTs(
        uint256[] calldata ids,
        address recipient
    ) external poolOwnedByContract(recipient) {
        // LSSVMPairFactory.depositNFTs
        ERC721 _nft = ERC721(address(collection));
        for(uint256 i = 0; i < ids.length; i++) {
            collection.transferFrom(msg.sender, address(this), ids[i]);
        }
        collection.setApprovalForAll(address(sudoFactory), true);
        sudoFactory.depositNFTs(_nft, ids, recipient);
    }

    function withdrawNFT(
        address _pool,
        uint256[] calldata _ids
    ) external ownerCaller(_pool) poolActive(_pool) poolOwnedByContract(_pool) {
        LSSVMPair(_pool).withdrawERC721(collection, _ids);
    }

    function withdrawETH(
        address _pool,
        uint256 _amount
    ) external ownerCaller(_pool) poolOwnedByContract(_pool) {
        require(!pairing[_pool].active, "There is a duplicate active within this pool.");
        LSSVMPairETH(payable(_pool)).withdrawETH(_amount);
    }

    function changeSpotPrice(
        address _pool,
        uint128 newSpotPrice
    ) external ownerCaller(_pool) poolActive(_pool) poolOwnedByContract(_pool) {
        LSSVMPair(_pool).changeSpotPrice(newSpotPrice);
    }

    function changeDelta(
        address _pool,
        uint128 newDelta
    ) external ownerCaller(_pool) poolActive(_pool) poolOwnedByContract(_pool) {
        LSSVMPair(_pool).changeDelta(newDelta);
    }

    function changeFee(
        address _pool,
        uint96 newFee
    ) external ownerCaller(_pool) poolActive(_pool) poolOwnedByContract(_pool) {
        LSSVMPair(_pool).changeFee(newFee);
    }

    function changeAssetRecipient(
        address _pool,
        address payable newRecipient
    ) external ownerCaller(_pool) poolActive(_pool) poolOwnedByContract(_pool) {
        LSSVMPair(_pool).changeAssetRecipient(newRecipient);
    }

    function borrow(
        address _lendingContract,
        bytes32[] calldata _merkleProof, 
        address _spotPool,
        address _sudoPool,
        uint256 _id,
        uint256 _lpTokenId,
        uint256 _amount
    ) external poolOwnedByContract(_sudoPool) {
        // Create reflection NFT
        require(_lpTokenId < totalSupply);
        require(!idExistence[_lpTokenId], "LpIdAlreadyTaken");
        if(ownerOf(_id) == address(0)) {
            _mint(address(this), _lpTokenId);
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
        require(currentPrice >= 110 * (_amount + currentlyBorrowed) / 100, "Listing price must be 10% greater than borrow amount");
        address currency = address(Vault(_spotPool).token());
        pairing[_sudoPool].amountActive++;
        // Execute borrow against LP position
        Lend(payable(_lendingContract)).borrow(_merkleProof, _spotPool, address(this), _lpTokenId, _amount);
        require(IERC20(currency).transfer(msg.sender, _amount), "Transfer failed");
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
        IERC20(currency).approve(_lendingContract, amount);
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
        (,address spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
        address currency = address(Vault(spotPool).token());
        IERC20(currency).approve(_lendingContract, _amount);
        // Call pay interest 
        Lend(payable(_lendingContract)).repay(address(this), _lpTokenId, _amount);
        (, spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
        if(spotPool == address(0)) {
            pairing[_sudoPool].amountActive--;
            _burn(_lpTokenId);
        }
        if(pairing[_sudoPool].amountActive == 0) {
            pairing[_sudoPool].active = false;
            delete pairing[_sudoPool].price;
        }
    }

    function liquidateLp(
        address _sudoPool,
        address _lendingContract,
        uint256 _lpTokenId,
        uint256[] calldata _ids,
        uint256[] calldata _epoch
    ) external {
        (, address spotPool,,,uint256 loanAmount,) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
        Vault vault = Vault(payable(spotPool));
        uint256 futurePayout = vault.getPayoutPerReservation(
            (block.timestamp - vault.startTime() + vault.epochLength() / 6 + 4 hours) / vault.epochLength()
        );
        uint256 outstandingInterest = Lend(payable(_lendingContract)).getInterestPayment(_epoch, address(this), _lpTokenId);
        // contract checks borrow position on lending contract 
            // if within LP liquidation window + base liquidation window, can liquidate
            // else revert
        // if liquidation goes through
            // liquidator sends borrow currency to contract
            // use currency to pay down debt + interest
            // liquidator gains control of the NFT or underlying spot price value 
        if(loanAmount > futurePayout) {
            vault.token().transferFrom(msg.sender, address(this), loanAmount + outstandingInterest);
            vault.token().approve(_lendingContract, outstandingInterest);
            // Call pay interest 
            Lend(payable(_lendingContract)).payInterest(_epoch, address(this), _lpTokenId);
            vault.token().approve(_lendingContract, loanAmount);
            // Call pay interest 
            Lend(payable(_lendingContract)).repay(address(this), _lpTokenId, loanAmount);
            (, spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _lpTokenId);
            if(spotPool == address(0)) {
                pairing[_sudoPool].amountActive--;
                _burn(_lpTokenId);
            }
        } else {
            revert("Liquidation failed");
        }
        // LP NFT destroyed
            // if NFT is in pool, liquidator receives NFT
            // else liquidator receives spot price worth of ETH
        uint256 ETHpayout = pairing[_sudoPool].price;
        if(collection.ownerOf(_ids[0]) == _sudoPool) {
            LSSVMPair(_sudoPool).withdrawERC721(collection, _ids);
            collection.transferFrom(address(this), msg.sender, _ids[0]);
        } else {
            LSSVMPairETH(payable(_sudoPool)).withdrawETH(ETHpayout);
            payable(msg.sender).transfer(ETHpayout);
        }
        if(pairing[_sudoPool].amountActive == 0) {
            pairing[_sudoPool].active = false;
            delete pairing[_sudoPool].price;
        }
    }

    function onOwnershipTransfer(address oldOwner) external {
        require(ILSSVMPairFactoryLike(address(sudoFactory)).isPair(msg.sender, LSSVMPair(msg.sender).pairVariant()), "FAKER!!!");
        require(owner() == address(this));
        pairing[msg.sender].active = true;
    }
}