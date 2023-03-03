//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Vault } from "./Vault.sol";
import { IFactory } from "../abacusInterfaces/IFactory.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./ReentrancyGuard.sol";
import "hardhat/console.sol";

               //\\                 ||||||||||||||||||||||||||                   //\\                 ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
              ///\\\                |||||||||||||||||||||||||||                 ///\\\                ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
             ////\\\\               |||||||             ||||||||               ////\\\\               ||||||||||||||||||||||||||||  ||||||||            ||||||||  ||||||||||||||||||||||||||||
            /////\\\\\              |||||||             ||||||||              /////\\\\\              |||||||                       ||||||||            ||||||||  ||||||||||
           //////\\\\\\             |||||||             ||||||||             //////\\\\\\             |||||||                       ||||||||            ||||||||  ||||||||||
          ///////\\\\\\\            |||||||             ||||||||            ///////\\\\\\\            |||||||                       ||||||||            ||||||||  ||||||||||
         ////////\\\\\\\\           ||||||||||||||||||||||||||||           ////////\\\\\\\\           |||||||                       ||||||||            ||||||||  ||||||||||
        /////////\\\\\\\\\          ||||||||||||||                        /////////\\\\\\\\\          |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
       /////////  \\\\\\\\\         ||||||||||||||||||||||||||||         /////////  \\\\\\\\\         |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
      /////////    \\\\\\\\\        |||||||             ||||||||        /////////    \\\\\\\\\        |||||||                       ||||||||            ||||||||  ||||||||||||||||||||||||||||
     /////////||||||\\\\\\\\\       |||||||             ||||||||       /////////||||||\\\\\\\\\       |||||||                       ||||||||            ||||||||                    ||||||||||
    /////////||||||||\\\\\\\\\      |||||||             ||||||||      /////////||||||||\\\\\\\\\      |||||||                       ||||||||            ||||||||                    ||||||||||
   /////////          \\\\\\\\\     |||||||             ||||||||     /////////          \\\\\\\\\     |||||||                       ||||||||            ||||||||                    ||||||||||
  /////////            \\\\\\\\\    |||||||             ||||||||    /////////            \\\\\\\\\    ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||
 /////////              \\\\\\\\\   |||||||||||||||||||||||||||    /////////              \\\\\\\\\   ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||
/////////                \\\\\\\\\  ||||||||||||||||||||||||||    /////////                \\\\\\\\\  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||  ||||||||||||||||||||||||||||

/// @title NFT closure contract
/// @author Gio Medici
/// @notice Operates the post NFT closure auction
contract Closure is ReentrancyGuard, Initializable {
    
    /* ======== ADDRESS ======== */
    IFactory public factory;
    Vault public vault;
    ERC20 public token;
    AbacusController public controller;

    /* ======== UINT ======== */
    /// @notice track the amount of ongoing auctions
    uint256 public liveAuctions;

    /* ======== MAPPING ======== */
    /// FOR ALL OF THE FOLLOWING MAPPINGS THE FIRST TWO VARIABLES ARE
    /// [uint256] -> nonce
    /// [address] -> NFT collection address
    /// [uint256] -> NFT ID

    /// @notice Current closure nonce for an NFT
    mapping(address => mapping(uint256 => uint256)) public nonce;

    /// @notice track NFT value ascribed by the pool
    /// [uint256] -> pool ascribed valuation
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public nftVal;

    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public gracePeriodEndTime;

    /// @notice track highest bid in an auction
    /// [uint256] -> highest bid
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public highestBidGrace;

    /// @notice track the highest bidder in an auction
    /// [address] -> higher bidder
    mapping(uint256 => mapping(address => mapping(uint256 => address))) public highestBidderGrace;

    /// @notice track auction end time
    /// [uint256] -> auction end time 
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public auctionEndTime;

    /// @notice track highest bid in an auction
    /// [uint256] -> highest bid
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public highestBid;

    /// @notice track the highest bidder in an auction
    /// [address] -> higher bidder
    mapping(uint256 => mapping(address => mapping(uint256 => address))) public highestBidder;

    /// @notice track auction completion status
    /// [bool] -> auction completion status
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public auctionComplete;

    /* ======== EVENTS ======== */
    event NewBid(address _pool, address _token, uint256 _closureNonce, address _closePoolContract, address _collection, uint256 _id, address _bidder, uint256 _bid);
    event AuctionEnded(address _pool, uint256 _closureNonce, address _closePoolContract, address _collection, uint256 _id, address _winner, uint256 _highestBid);
    event NftClaimed(address _pool, uint256 _closureNonce, address _closePoolContract, address _collection, uint256 _id, address _winner);

    /* ======== CONSTRUCTOR ======== */
    function initialize(
        address _vault,
        address _controller
    ) external initializer {
        vault = Vault(payable(_vault));
        token = ERC20(vault.token());
        controller = AbacusController(_controller);
        factory = IFactory(controller.factory());
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== AUCTION ======== */
    /// SEE IClosure.sol FOR COMMENTS
    function startAuction(uint256 _nftVal, address _nft, uint256 _id) external {
        require(msg.sender == address(vault));
        nonce[_nft][_id]++;
        nftVal[nonce[_nft][_id]][_nft][_id] = _nftVal;
        gracePeriodEndTime[nonce[_nft][_id]][_nft][_id] = block.timestamp + vault.graceLength();
        liveAuctions++;
    }

    function newGracePeriodBid(
        uint256[] calldata _nonces, 
        address[] calldata _nfts, 
        uint256[] calldata _ids
    ) external nonReentrant {
        uint256 totalPurchaseCost;
        uint256 totalReturnAmount;
        for(uint256 i = 0; i < _nfts.length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            uint256 _nonce = nonce[_nft][_id];
            (uint256 _addedReturn, ) = _updateProtocol(
                msg.sender, 
                _nonces, 
                _nft, 
                _id, 
                _nonce
            );
            totalReturnAmount += _addedReturn;
            totalPurchaseCost += nftVal[_nonce][_nft][_id];
        }
        require(
            token.transfer(address(factory), totalReturnAmount)
            , "Bid return failed"
        );  
        require(
            vault.token().transferFrom(msg.sender, address(this), totalPurchaseCost)
            , "Purchase transfer failed"
        );
    }

    /// SEE IClosure.sol FOR COMMENTS
    function newBid(
        address[] calldata _nfts, 
        uint256[] calldata _ids, 
        uint256[] calldata _amounts
    ) external nonReentrant {
        uint256 totalBidAmount;
        uint256 totalReturnAmount;
        for(uint256 i = 0; i < _nfts.length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            uint256 _amount = _amounts[i];
            uint256 _nonce = nonce[_nft][_id];
            require(
                block.timestamp > gracePeriodEndTime[_nonce][_nft][_id]
                && highestBidderGrace[_nonce][_nft][_id] == address(0)
                , "LP grace period ongoing"
            );
            if(
                nftVal[_nonce][_nft][_id] != 0
                && auctionEndTime[_nonce][_nft][_id] == 0
            ) {
                auctionEndTime[_nonce][_nft][_id] = block.timestamp + vault.auctionLength();
            }
            require(
                _amount > 10**token.decimals() / 10000
                , "Min bid must be greater than 0.0001 tokens"
            );
            require(
                _amount > 101 * highestBid[_nonce][_nft][_id] / 100
                , "Invalid bid"
            );
            require(
                block.timestamp < auctionEndTime[_nonce][_nft][_id]
                , "Time over"
            );
            totalReturnAmount += highestBid[_nonce][_nft][_id];
            factory.updatePendingReturns(
                highestBidder[_nonce][_nft][_id], 
                address(token), 
                highestBid[_nonce][_nft][_id]
            );
            totalBidAmount += _amount;
            highestBid[_nonce][_nft][_id] = _amount;
            highestBidder[_nonce][_nft][_id] = msg.sender;
            emit NewBid(
                address(vault),
                address(vault.token()),
                _nonce,
                address(this), 
                _nft, 
                _id, 
                msg.sender, 
                _amount
            );
        }
        require(
            token.transfer(address(factory), totalReturnAmount)
            , "Bid return failed"
        );
        require(
            token.transferFrom(msg.sender, address(this), totalBidAmount)
            , "Bid transfer failed"
        );
    }

    /// SEE IClosure.sol FOR COMMENTS
    function endAuction(
        address[] calldata _nfts, 
        uint256[] calldata _ids
    ) external nonReentrant {
        uint256 totalTransferAmount;
        for(uint256 i = 0; i < _nfts.length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            uint256 _nonce = nonce[_nft][_id];
            uint256 transferAmount;
            bool purchaseState;
            if(highestBidderGrace[_nonce][_nft][_id] == address(0)) {
                require(
                    auctionEndTime[_nonce][_nft][_id] != 0
                    , "Invalid auction"
                );
                require(
                    block.timestamp > auctionEndTime[_nonce][_nft][_id]
                    && !auctionComplete[_nonce][_nft][_id],
                    "Auction ongoing - EA"
                );
                transferAmount = highestBid[_nonce][_nft][_id];            
            } else {
                require(
                    gracePeriodEndTime[_nonce][_nft][_id] != 0
                    , "Invalid auction"
                );
                require(
                    block.timestamp > gracePeriodEndTime[_nonce][_nft][_id]
                    && !auctionComplete[_nonce][_nft][_id],
                    "Grace auction ongoing - EA"
                );
                purchaseState = true;
                transferAmount = nftVal[_nonce][_nft][_id];
            }
            vault.updateSaleValue(purchaseState, _nft, _id, highestBid[_nonce][_nft][_id]);
            totalTransferAmount += transferAmount;
            auctionComplete[_nonce][_nft][_id] = true;
            emit AuctionEnded(
                address(vault), 
                _nonce, 
                address(this), 
                _nft, 
                _id, 
                highestBidder[_nonce][_nft][_id], 
                highestBid[_nonce][_nft][_id]
            );
        }
        token.transfer(address(vault), totalTransferAmount);
        liveAuctions -= _nfts.length;
    }

    function claimNft(
        address[] calldata _nfts, 
        uint256[] calldata _ids
    ) external nonReentrant {
        for(uint256 i = 0; i < _nfts.length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            uint256 _nonce = nonce[_nft][_id];
            require(
                auctionComplete[_nonce][_nft][_id]
                , "Auction ongoing - CN"
            );
            address winner;
            if(highestBidderGrace[_nonce][_nft][_id] != address(0)) {
                winner = highestBidderGrace[_nonce][_nft][_id];
            } else {
                winner = highestBidder[_nonce][_nft][_id];
            }
            IERC721(_nft).safeTransferFrom(
                address(this), 
                winner,
                _id
            );
            emit NftClaimed(
                address(vault), 
                _nonce, 
                address(this), 
                _nft, 
                _id, 
                winner
            );
        }
    }

    function _updateProtocol(
        address _user, 
        uint256[] calldata _nonces, 
        address _nft, 
        uint256 _id, 
        uint256 _nonce
    ) internal returns(uint256 totalReturnAmount, uint256 totalPurchaseCost) {
        uint256 netRiskPoints = this.getActiveUserRiskPoints(_user, _nonces, _nft, _id);
        require(
            block.timestamp < gracePeriodEndTime[nonce[_nft][_id]][_nft][_id]
            , "Grace period auction has concluded!"
        );
        require(
            netRiskPoints > highestBidGrace[_nonce][_nft][_id]
            , "Must have more risk points than existing bidder!"
        );
        if(highestBidderGrace[_nonce][_nft][_id] != address(0)) {
            factory.updatePendingReturns(
                highestBidder[_nonce][_nft][_id], 
                address(token),
                nftVal[_nonce][_nft][_id]
            );
            totalReturnAmount += nftVal[_nonce][_nft][_id];
        }
        totalPurchaseCost += nftVal[_nonce][_nft][_id];
        highestBidGrace[_nonce][_nft][_id] = netRiskPoints;
        highestBidderGrace[_nonce][_nft][_id] = _user;
    }

    function getActiveUserRiskPoints(
        address _user,
        uint256[] calldata _nonces,
        address _nft,
        uint256 _id
    ) external view returns(uint256 activeRiskPoints) {
        uint256 totalLoss;
        uint256 totalGain;
        for(uint256 i = 0; i < _nonces.length; i++) {
            uint256 _nonce = _nonces[i];
            (
                bool active,
                uint256 startEpoch,
                uint256 unlockEpoch,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
            ) = vault.traderProfile(_user,_nonce);
            if(
                !active 
                || unlockEpoch <= getClosureEpoch(_nft, _id)
                || startEpoch > getClosureEpoch(_nft, _id)
            ) {
                continue;
            }
            if(getClosureEpoch(_nft, _id) == startEpoch) {
                uint256 riskStart = getRiskStart(_user, _nonce);
                uint256 riskStartLost = getRiskStartLost(_user, _nonce);
                totalLoss +=
                    riskStart > riskStartLost ? 
                        riskStartLost : riskStart;
                totalGain +=
                    riskStart > riskStartLost ? 
                        (riskStart - riskStartLost) : 0;
            } else {
                uint256 riskPoints = getRisk(_user, _nonce);
                uint256 riskLost = getRiskLost(_user, _nonce);
                totalLoss +=
                    riskPoints > riskLost ? 
                        riskLost : riskPoints;
                totalGain +=
                    riskPoints > riskLost ? 
                        (riskPoints - riskLost) : 0;
            }
        }
        activeRiskPoints = totalGain > totalLoss ? totalGain - totalLoss : 0;
    }

    function getRisk(address _user, uint256 _nonce) public view returns(uint256 riskPoints) {
        (,,,,riskPoints,,,,,,,) = vault.traderProfile(_user, _nonce);
    }
    
    function getRiskStart(address _user, uint256 _nonce) public view returns(uint256 riskStart) {
        (,,,riskStart,,,,,,,,) = vault.traderProfile(_user, _nonce);
    }

    function getRiskLost(address _user, uint256 _nonce) public view returns(uint256 riskLost) {
        (,,,,,,riskLost,,,,,) = vault.traderProfile(_user, _nonce);
    }

    function getRiskStartLost(address _user, uint256 _nonce) public view returns(uint256 riskStartLost) {
        (,,,,,riskStartLost,,,,,,) = vault.traderProfile(_user, _nonce);
    }

    function getClosureEpoch(address _nft, uint256 _id) public view returns(uint256 closureEpoch) {
        uint256 _nonce = nonce[_nft][_id];
        closureEpoch = (gracePeriodEndTime[_nonce][_nft][_id] - vault.startTime() - vault.graceLength()) / vault.epochLength();
    }
}