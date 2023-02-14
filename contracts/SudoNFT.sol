//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { LSSVMPair } from "./sudoHelpers/LSSVMPair.sol";
import { LSSVMPairETH } from "./sudoHelpers/LSSVMPairETH.sol";
import { Vault } from "./abacusHelpers/Vault.sol";
import { Lend } from "./abacusHelpers/Lend.sol";

import { IVault } from "./abacusInterfaces/IVault.sol";
import { ILend } from "./abacusInterfaces/ILend.sol";
import { ILSSVMPairFactory } from "./sudoInterfaces/ILSSVMPairFactory.sol";
import { ICurve } from "./sudoInterfaces/ICurve.sol";

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SudoNft is ERC721 {

    ERC721 public collection;
    ILSSVMPairFactory public sudoFactory;

    mapping(address => Pairing) public pairing;
    mapping(uint256 => NFTInfo) public NFT;

    struct Pairing {
        bool active;
        address owner;
        uint256 amountActive;
        //helloworld
    }

    struct NFTInfo {
        bool active;
        address owner;
        address sudoPool;
    }

    modifier ownerCaller(address _pool) {
        require(msg.sender == pairing[_pool].owner);
        _;
    }

    modifier duplicateActive(uint256 _id) {
        require(!NFT[_id].active);
        _;
    }

    modifier poolActive(address _pool) {
        require(!pairing[_pool].active);
        _;
    }

    constructor(
        address _factoryAddress,
        address _collection
    ) ERC721(ERC721(_collection).name(), ERC721(_collection).symbol()) {
        sudoFactory = ILSSVMPairFactory(_factoryAddress);
        collection = ERC721(_collection);
    }

    function createPairEth(
        IERC721 _nft,
        ICurve _bondingCurve,
        address payable _assetRecipient,
        LSSVMPair.PoolType _poolType,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) external {
        // LSSVMPairFactory.createPairETH
        LSSVMPairETH newPool = sudoFactory.createPairETH(
            _nft, 
            _bondingCurve, 
            _assetRecipient, 
            _poolType, 
            _delta,
            _fee, 
            _spotPrice, 
            _initialNFTIDs
        );

        // Track pool owner
        pairing[address(newPool)].owner = msg.sender;
    }

    function depositNFTs(
        uint256[] calldata ids,
        address recipient
    ) external {
        // LSSVMPairFactory.depositNFTs
        ERC721 _nft = ERC721(address(collection));
        for(uint256 i = 0; i < ids.length; i++) {
            collection.transferFrom(msg.sender, address(this), ids[i]);
            collection.approve(address(sudoFactory), ids[i]);
            // Connect deposited NFTs to a pair nonce
            NFT[ids[i]].owner = msg.sender;
        }
        sudoFactory.depositNFTs(_nft, ids, recipient);
    }

    function withdrawNFT(
        address _pool,
        uint256[] calldata _ids
    ) external {
        for(uint256 i = 0; i < _ids.length; i++) {
            require(!NFT[_ids[i]].active, "One of NFTs has live duplicate");
            require(NFT[_ids[i]].owner == msg.sender, "Only the owner can withdraw");
        }
        LSSVMPair(_pool).withdrawERC721(collection, _ids);
    }

    function withdrawETH(
        address _pool,
        uint256 _amount
    ) external ownerCaller(_pool) {
        require(!pairing[_pool].active, "There is a duplicate active within this pool.");
        LSSVMPairETH(payable(_pool)).withdrawETH(_amount);
    }

    function changeSpotPrice(
        address _pool,
        uint128 newSpotPrice
    ) external ownerCaller(_pool) poolActive(_pool) {
        LSSVMPair(_pool).changeSpotPrice(newSpotPrice);
    }

    function changeDelta(
        address _pool,
        uint128 newDelta
    ) external ownerCaller(_pool) poolActive(_pool) {
        LSSVMPair(_pool).changeDelta(newDelta);
    }

    function changeFee(
        address _pool,
        uint96 newFee
    ) external ownerCaller(_pool) poolActive(_pool) {
        LSSVMPair(_pool).changeFee(newFee);
    }

    function changeAssetRecipient(
        address _pool,
        address payable newRecipient
    ) external ownerCaller(_pool) poolActive(_pool) {
        LSSVMPair(_pool).changeAssetRecipient(newRecipient);
    }

    function borrow(
        address _lendingContract,
        bytes32[] calldata _merkleProof, 
        address _spotPool,
        address _sudoPool,
        uint256 _id,
        uint256 _amount
    ) external {
        // Create reflection NFT
        require(NFT[_id].owner == msg.sender);
        require(ownerOf(_id) == address(0));
        _mint(address(this), _id);
        // amount must be 10% less than listing price
        require(LSSVMPair(_sudoPool).spotPrice() >= 110 * _amount / 100);
        address currency = address(Vault(_spotPool).token());
        pairing[_sudoPool].active = true;
        pairing[_sudoPool].amountActive++;
        NFT[_id].active = true;
        // Execute borrow against LP position
        ILend(_lendingContract).borrow(_merkleProof, _spotPool, address(this), _id, _amount);
        require(IERC20(currency).transfer(msg.sender, _amount));        
    }

    function payInterest(
        address _lendingContract,
        uint256[] calldata _epoch,
        uint256 _id
    ) external {
        // Basic pay interest transitory
        // Calculate interest cost 
        uint256 amount = ILend(_lendingContract).getInterestPayment(_epoch, address(this), _id);
        // Approve lending contract to take that amount
        (,address spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _id);
        address currency = address(Vault(spotPool).token());
        IERC20(currency).approve(_lendingContract, amount);
        // Call pay interest 
        ILend(_lendingContract).payInterest(_epoch, address(this), _id);
    }

    function repay(
        address _lendingContract,
        uint256 _id, 
        uint256 _amount
    ) external {
        // Basic repay transitory
        // Approve lending contract to take that amount
        address sudoPool = collection.ownerOf(_id);
        (,address spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _id);
        address currency = address(Vault(spotPool).token());
        IERC20(currency).approve(_lendingContract, _amount);
        // Call pay interest 
        ILend(_lendingContract).repay(address(this), _id, _amount);
        (, spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _id);
        if(spotPool == address(0)) {
            pairing[sudoPool].amountActive--;
            NFT[_id].active = false;
            _burn(_id);
        }
        if(pairing[sudoPool].amountActive == 0) {
            pairing[sudoPool].active = false;
        }
    }

    function liquidateLp(
        address _lendingContract,
        uint256[] calldata _ids,
        uint256[] calldata _epoch
    ) external {
        uint256 _id = _ids[0];
        (, address spotPool,,,uint256 loanAmount,) = Lend(payable(_lendingContract)).loans(address(this), _id);
        Vault vault = Vault(payable(spotPool));
        address sudoPool = NFT[_id].sudoPool;
        uint256 futureEpoch = (block.timestamp - vault.startTime() + vault.epochLength() / 6 + 4 hours) / vault.epochLength();
        uint256 futurePayout = vault.getPayoutPerReservation(futureEpoch);
        uint256 outstandingInterest = ILend(_lendingContract).getInterestPayment(_epoch, address(this), _id);
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
            ILend(_lendingContract).payInterest(_epoch, address(this), _id);
            vault.token().approve(_lendingContract, loanAmount);
            // Call pay interest 
            ILend(_lendingContract).repay(address(this), _id, loanAmount);
            (, spotPool,,,,) = Lend(payable(_lendingContract)).loans(address(this), _id);
            if(spotPool == address(0)) {
                pairing[sudoPool].amountActive--;
                NFT[_id].active = false;
                _burn(_id);
            }
            if(pairing[sudoPool].amountActive == 0) {
                pairing[sudoPool].active = false;
            }
        } else {
            revert("Liquidation failed");
        }
        // LP NFT destroyed
            // if NFT is in pool, liquidator receives NFT
            // else liquidator receives spot price worth of ETH
        if(collection.ownerOf(_id) == sudoPool) {
            LSSVMPair(sudoPool).withdrawERC721(collection, _ids);
            collection.transferFrom(address(this), msg.sender, _id);
        } else {
            LSSVMPairETH(payable(sudoPool)).withdrawETH(LSSVMPair(payable(sudoPool)).spotPrice());
            payable(msg.sender).transfer(LSSVMPair(payable(sudoPool)).spotPrice());
        }
    }
}