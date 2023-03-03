//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AbacusController } from "./AbacusController.sol";
import { Closure } from "./Closure.sol";
import { Lend } from "./Lend.sol";
import { IClosure } from "../abacusInterfaces/IClosure.sol";
import { IFactory } from "../abacusInterfaces/IFactory.sol";
import { BitShift } from "./BitShift.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ReentrancyGuard.sol";
import "./ReentrancyGuard2.sol";
// import "hardhat/console.sol";


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

/// @title Spot pool
/// @author Gio Medici
/// @notice Spot pools allow users to collateralize any combination of NFT collections and IDs
contract Vault is ReentrancyGuard, ReentrancyGuard2, Initializable {

    /* ======== ADDRESS ======== */
    IFactory factory;
    AbacusController controller;
    ERC20 public token;
    address creator;
    address private _closePoolMultiImplementation;

    /// @notice Address of the deployed closure contract
    Closure public closePoolContract;

    /* ======== STRING ======== */
    enum Stage{ INITIALIZED, INCLUDED_NFT }
    Stage stage;

    /* ======== STRING ======== */
    string name;
    
    /* ======== BYTES32 ======== */

    bytes32 public root;

    /* ======== UINT ======== */
    uint256 riskBase;
    uint256 riskStep;

    uint256 public graceLength;

    uint256 public auctionLength;

    uint256 public collectionAmount;

    uint256 public modTokenDecimal;

    uint256 public resetEpoch;

    uint256 public epochLength;

    /// @notice Interest rate that the pool charges for usage of liquidity
    uint256 public interestRate;

    uint256 public spotsRemoved;

    uint256 public reservations;

    /// @notice Total amount of slots to be collateralized
    uint256 public amountNft;

    /// @notice Pool creation time
    uint256 public startTime;

    /// @notice Pool tranche size
    uint256 public ticketLimit;

    /// @notice Total amount of adjustments required (every time an NFT is 
    /// closed this value increments)
    uint256 public adjustmentsRequired;

    /* ======== MAPPINGS ======== */
    mapping(address => bool) addressExists;
    mapping(uint256 => bool) nftClosed;
    mapping(uint256 => uint256[]) ticketsPurchased;
    mapping(address => mapping(uint256 => uint256)) closureNonce;
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) closureNegated;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) adjustmentNonce;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) epochOfClosure;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) payoutInfo;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) auctionSaleValue;
    mapping(address => mapping(uint256 => uint256)) tokenMapping;
    mapping(uint256 => uint256) compressedEpochVals;
    mapping(address => mapping(uint256 => address)) allowanceTracker;
    
    /// @notice A users position nonce
    /// [address] -> User address
    /// [uint256] -> Next nonce value 
    mapping(address => uint256) public positionNonce;

    /// @notice Payout size for each reservation during an epoch
    /// [uint256] -> epoch
    /// [uint256] -> payout size
    mapping(uint256 => uint256) public epochEarnings;

    /// @notice Tracking the adjustments made by each user for each open nonce
    /// [address] -> user
    /// [uint256] -> nonce
    /// [uint256] -> amount of adjustments made
    mapping(address => mapping(uint256 => uint256)) public adjustmentsMade;

    /// @notice Track a traders profile for each nonce
    /// [address] -> user
    /// [uint256] -> nonce
    mapping(address => mapping(uint256 => Buyer)) public traderProfile;

    /// @notice Track adjustment status of closed NFTs
    /// [address] -> User 
    /// [uint256] -> nonce
    /// [address] -> NFT collection
    /// [uint256] -> NFT ID
    /// [bool] -> Status of adjustment
    mapping(address => mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => bool))))) public adjustCompleted;

    /* ======== STRUCTS ======== */
    /// @notice Holds core metrics for each trader
    /// [active] -> track if a position is closed
    /// [multiplier] -> the multiplier applied to a users credit intake when closing a position
    /// [startEpoch] -> epoch that the position was opened
    /// [unlockEpoch] -> epoch that the position can be closed
    /// [comListOfTickets] -> compressed (using bit shifts) value containing the list of tranches
    /// [comAmountPerTicket] -> compressed (using bit shifts) value containing the list of amounts
    /// of tokens purchased in each tranche
    /// [ethLocked] -> total amount of eth locked in the position
    struct Buyer {
        bool active;
        uint32 startEpoch;
        uint32 unlockEpoch;
        uint32 riskStart;
        uint32 riskPoints;
        uint32 riskStartLost;
        uint32 riskLost;
        uint128 tokensLocked;
        uint128 tokensStatic;
        uint128 tokensLost;
        uint256 comListOfTickets;
        uint256 comAmountPerTicket;
    }

    /* ======== EVENTS ======== */
    event NftInclusion(address[] nfts, uint256[] ids);
    event VaultBegun(address _token, uint256 _riskBase, uint256 _riskStep, uint256 _collateralSlots, uint256 _ticketSize, uint256 _interest, uint256 _epoch);
    event Purchase(address _buyer, uint256[] tickets, uint256[] amountPerTicket, uint256 nonce, uint256 startEpoch, uint256 finalEpoch);
    event SaleComplete(address _seller, uint256 nonce, uint256 ticketsSold, uint256 creditsPurchased);
    event NftClosed(uint256 _adjustmentNonce, uint256 _closureNonce, address _collection, uint256 _id, address _caller, uint256 payout, address closePoolContract); 
    event FeesEarned(address _pool, uint256 _epoch, uint256 _fees);
    event LPTransferAllowanceChanged(address from, address to);
    event LPTransferred(address from, address to, uint256 nonce);
    event PrincipalCalculated(address _closePoolContract, address _collection, uint256 _id, address _user, uint256 _nonce, uint256 _closureNonce);

    /* ======== CONSTRUCTOR ======== */
    function initialize(
        string memory _name,
        address _controller,
        address closePoolImplementation_,
        address _creator
    ) external initializer {
        controller = AbacusController(_controller);
        factory = IFactory(controller.factory());
        require(_creator != address(0));
        require(closePoolImplementation_ != address(0));
        creator = _creator;
        stage = Stage.INITIALIZED;
        name = _name;
        _closePoolMultiImplementation = closePoolImplementation_;
        adjustmentsRequired = 1;
    }

    /* ======== CONFIGURATION ======== */
    /** 
    Error codes:
        NC - msg.sender not the creator (caller incorrect)
        AS - pool already started
        NO - NFTs with no owner are allowed
        AM - Already included (there exists a duplicate NFT submission)
    */
    function includeNft(
        bytes32 _root,
        address[] calldata _collection,
        uint256[] calldata _id
    ) external {
        require(msg.sender == creator);
        require(root == 0x0, "Inclusion finished");
        if(_root != 0x0) {
            root = _root;
            stage = Stage.INCLUDED_NFT;
        }
        uint256 length = _collection.length;
        for(uint256 i = 0; i < length; i++) {
            if(!addressExists[_collection[i]]) {
                addressExists[_collection[i]] = true;
                collectionAmount++;
            }
        }
        emit NftInclusion(_collection, _id);
    }

    /** 
    Error codes:
        NC - msg.sender not the creator (caller incorrect)
        AS - pool already started
        TTL - ticket size too low (min 10)
        TTH - ticket size too high (max 100000) 
        RTL - interest rate too low (min 10)
        RTH - interest rate too high (max 500000)
        ITSC - invalid ticket and slot count entry (max ticketSize * slot is 2^25)
        TLS - too little slots (min 1)
        TMS - too many slots (max 2^32)
        IRB - invalid risk base (min 11, max 999)
        IRS - invalid risk step (min 2, max 999)
    */
    function begin(
        uint32 _slots,
        uint256 _ticketSize,
        uint256 _rate,
        uint256 _epochLength,
        address _token,
        uint256 _riskBase,
        uint256 _riskStep,
        uint256 _auctionLength,
        uint256 _graceAuctionLength
    ) external {
        require(stage == Stage.INCLUDED_NFT);
        require(_token != address(0));
        require(
            _epochLength >= 1 days
            && _epochLength <= 2 weeks
            // , "Out of time bounds"
        );
        require(
            msg.sender == creator
            // , "NC"
        );
        require(
            _ticketSize >= 10
            // , "TTL"
        );
        require(
            _ticketSize <= 100000
            // , "TTH"
        );
        require(
            _rate >= 100
            // , "RTS"
        );
        require(
            _rate < 500000
            // , "RTH"
        );
        require(
            _slots * _ticketSize < 2**25
            // , "ITSC"
        );
        require(
            _slots > 0
            // , "TLS"
        );
        require(
            _slots < 2**32
            // , "TMS"
        );
        require(
            _riskBase < 1000
            && _riskBase >= 1
            // , "IRB"
        );
        require(
            _riskStep >= 1
            && _riskStep < 1000
            // , "IRS"
        );
        require(ERC20(_token).decimals() > 3);
        epochLength = _epochLength;
        amountNft = _slots;
        ticketLimit = _ticketSize;
        interestRate = _rate;
        riskBase = _riskBase;
        riskStep = _riskStep;
        startTime = block.timestamp;
        token = ERC20(_token);
        modTokenDecimal = 10**ERC20(_token).decimals() / 1000;
        graceLength = _graceAuctionLength;
        auctionLength = _auctionLength;
        emit VaultBegun(address(token), _riskBase, _riskStep, _slots, _ticketSize, _rate, _epochLength);
    }

    /* ======== TRADING ======== */
    /** 
    Error codes:
        NS - pool hasn’t started yet
        II - invalid input (ticket length and amount per ticket length don’t match up)
        PTL - position too large (tried to purchase from too many tickets at once, max 100)
        IT - invalid startEpoch submission
        TS - lock time too short (finalEpoch needs to be more than 1 epoch greater than startEpoch)
        TL -  lock time too long (finalEpoch needs to be at most 10 epochs greater than startEpoch)
        ITA - invalid ticket amount (ticket amount submission cannot equal 0)
        TLE - ticket limit exceeded (this purchase will exceed the ticket limit of one of the chosen tranches)
    */
    function purchase(
        address _buyer,
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint32 startEpoch,
        uint32 finalEpoch
    ) external nonReentrant {
        require(_buyer != address(0));
        require(tickets.length >= 1);
        require(
            startTime != 0
            // , "NS"
        );
        require(
            tickets.length == amountPerTicket.length
            // , "II"
        );
        require(
            tickets.length <= 100
            // , "PTL"
        );
        require(
            startEpoch == (block.timestamp - startTime) / epochLength
            || startEpoch == (block.timestamp - startTime) / epochLength + 1
            , "IT"
        );
        console.log((block.timestamp - startTime) / epochLength);
        require(
            finalEpoch - startEpoch > 1
            , "TS"
        );
        require(
            finalEpoch - startEpoch <= 10
            , "TL"
        );
        uint256 totalTokensRequested;
        uint256 largestTicket;
        uint256 riskStart;
        uint256 riskNorm;
        for(uint256 i = 0; i < tickets.length / 10 + 1; i++) {
            if(tickets.length % 10 == 0 && i == tickets.length / 10) break;
            uint256 tempVal;
            uint256 upperBound;
            if(10 + i * 10 > tickets.length) {
                upperBound = tickets.length;
            } else {
                upperBound = 10 + i * 10;
            }
            tempVal = choppedPosition(
                _buyer,
                tickets[0 + i * 10:upperBound],
                amountPerTicket[0 + i * 10:upperBound],
                startEpoch,
                finalEpoch
            );
            riskNorm += tempVal & (2**32 - 1);
            tempVal >>= 32;
            riskStart += tempVal & (2**32 - 1);
            tempVal >>= 32;
            if(tempVal > largestTicket) largestTicket = tempVal;
        }
        riskNorm <<= 128;
        riskNorm |= riskStart;
        totalTokensRequested = updateProtocol(
            largestTicket,
            startEpoch,
            finalEpoch,
            tickets,
            amountPerTicket,
            riskNorm
        );
        require(token.transferFrom(msg.sender, address(this), totalTokensRequested * modTokenDecimal));
    }

    /** 
    Error codes:
        IC - improper caller (caller doesn’t own the position)
        PC - Position closed (users already closed their position)
        ANM - Proper adjustments have not been made (further adjustments required before being able to close)
        PNE - Position non-existent (no position exists with this nonce)
        USPE - Unable to sell position early (means the pool is in use)
    */
    function sell(
        uint256 _nonce
    ) external nonReentrant returns(uint256 payout, uint256 lost) {
        Buyer storage trader = traderProfile[msg.sender][_nonce];
        require(
            trader.active
            , "PC"
        );
        require(
            adjustmentsMade[msg.sender][_nonce] == adjustmentsRequired
            , "ANM"
        );
        require(
            trader.unlockEpoch != 0
            , "PNE"
        );
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        // console.log(poolEpoch, trader.startEpoch);
        require(
            trader.startEpoch <= poolEpoch
            , "EPCBS"
        );
        uint256 finalEpoch;
        if(poolEpoch >= trader.unlockEpoch) {
            finalEpoch = trader.unlockEpoch;
        } else {
            require(
                reservations == 0
                , "USPE"
            );
            finalEpoch = poolEpoch;
        }
        for(uint256 j = trader.startEpoch; j < finalEpoch; j++) {
            uint256 riskPoints = this.getRiskPoints(j);
            if(j == trader.startEpoch) {
                lost += (
                    trader.riskStart > trader.riskStartLost ? 
                        trader.riskStartLost : trader.riskStart
                    ) * epochEarnings[j] / riskPoints;
                payout += (
                    trader.riskStart > trader.riskStartLost ? 
                        (trader.riskStart - trader.riskStartLost) : 0
                    ) * epochEarnings[j] / riskPoints;
            } else {
                lost += (
                    trader.riskPoints > trader.riskLost ? 
                        trader.riskLost : trader.riskPoints
                    ) * epochEarnings[j] / riskPoints; 
                payout += (
                    trader.riskPoints > trader.riskLost ? 
                        (trader.riskPoints - trader.riskLost) : 0
                    ) * epochEarnings[j] / riskPoints;
            }
        }
        if(poolEpoch < trader.unlockEpoch) {
            for(poolEpoch; poolEpoch < trader.unlockEpoch; poolEpoch++) {
                uint256[] memory epochTickets = ticketsPurchased[poolEpoch];
                uint256 comTickets = trader.comListOfTickets;
                uint256 comAmounts = trader.comAmountPerTicket;
                while(comAmounts > 0) {
                    uint256 ticket = comTickets & (2**25 - 1);
                    uint256 amount = (comAmounts & (2**25 - 1)) / 100;
                    comTickets >>= 25;
                    comAmounts >>= 25;
                    uint256 temp = this.getTicketInfo(poolEpoch, ticket);
                    temp -= amount;
                    epochTickets[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1) 
                        - (2**(((ticket % 10))*25) - 1));
                    epochTickets[ticket / 10] |= (temp << ((ticket % 10)*25));
                }
                ticketsPurchased[poolEpoch] = epochTickets;
                uint256 tempComp = compressedEpochVals[poolEpoch];
                uint256 prevPosition;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 35) - 1) - (2**prevPosition - 1)) 
                        | (
                            (compressedEpochVals[poolEpoch] & (2**35 -1)) 
                            - (trader.tokensStatic / modTokenDecimal)
                        ); 
                prevPosition += 35;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 35) & (2**51 -1)) 
                                - (trader.startEpoch == poolEpoch ? trader.riskStart : trader.riskPoints)
                            ) << prevPosition
                        );
                prevPosition += 135;
                tempComp = 
                    tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                        | (
                            (
                                ((compressedEpochVals[poolEpoch] >> 170) & (2**84 -1)) 
                                - trader.tokensStatic
                            ) << prevPosition
                        );
                compressedEpochVals[poolEpoch] = tempComp;
            }
        }
        emit SaleComplete(
            msg.sender,
            _nonce,
            trader.comListOfTickets,
            payout
        );
        payout += trader.tokensLocked;
        lost += trader.tokensLost;
        require(token.transfer(controller.multisig(), lost));
        require(token.transfer(msg.sender, payout));
        delete traderProfile[msg.sender][_nonce].active;
    }

    /* ======== POSITION MOVEMENT ======== */
    function changeTransferPermission(
        address recipient,
        uint256 nonce
    ) external nonReentrant returns(bool) {
        allowanceTracker[msg.sender][nonce] = recipient;
        emit LPTransferAllowanceChanged(
            msg.sender,
            recipient
        );
        return true;
    }

    /** 
    Error chart:
        IC - invalid caller (caller is not the owner or doesn’t have permission)
        MAP - must adjust position (positions must be fully adjusted before being traded)
    */
    function transferFrom(
        address from,
        address to,
        uint256 nonce
    ) external nonReentrant returns(bool) {
        require(
            msg.sender == allowanceTracker[from][nonce] 
            || msg.sender == from
            // , "IC"
        );
        require(
            adjustmentsMade[from][nonce] == adjustmentsRequired
            // , "MAP"
        );
        adjustmentsMade[to][positionNonce[to]] = adjustmentsMade[from][nonce];
        traderProfile[to][positionNonce[to]] = traderProfile[from][nonce];
        positionNonce[to]++;
        delete allowanceTracker[from][nonce];
        delete traderProfile[from][nonce];
        emit LPTransferred(from, to, positionNonce[to] - 1);
        return true;
    }

    /* ======== POOL CLOSURE ======== */
    /** 
    Error chart: 
        TNA - token non-existent (chosen NFT to close does not exist in the pool) 
        PE0 - payout equal to 0 (payout must be greater than 0 to close an NFT) 
        NRA - no reservations available (all collateral spots are in use currently so closure is unavailable)
        TF - Transfer failed (transferring the NFT has failed so closure reverted)
    */
    function closeNft(
        bytes32[][] calldata _merkleProofs, 
        address[] calldata _nfts, 
        uint256[] calldata _ids
    ) external nonReentrant2 returns(uint256) {
        uint256 totalPayout;
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 ppr = this.getPayoutPerReservation(poolEpoch);
        uint256 temp = ppr;
        temp <<= 128;
        temp |= this.getRiskPoints(poolEpoch);
        require(
            ppr != 0
            , "PE0"
        );
        if(address(closePoolContract) == address(0)) {
            IClosure closePoolMultiDeployment = 
                IClosure(Clones.clone(_closePoolMultiImplementation));
            closePoolMultiDeployment.initialize(
                address(this),
                address(controller)
            );
            controller.addAccreditedAddressesMulti(address(closePoolMultiDeployment));
            closePoolContract = Closure(payable(address(closePoolMultiDeployment)));
        }
        nftClosed[poolEpoch] = true;
        for(uint256 i = 0; i < _nfts.length; i++) {
            bytes32[] memory _merkleProof = _merkleProofs[i];
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            require(
                this.getHeldTokenExistence(_merkleProof, _nft, _id)
                , "TNA"
            );
            adjustmentsRequired++;
            adjustmentNonce[_nft][_id][++closureNonce[_nft][_id]] = adjustmentsRequired;
            epochOfClosure[closureNonce[_nft][_id]][_nft][_id] = poolEpoch;
            payoutInfo[closureNonce[_nft][_id]][_nft][_id] = temp;
            uint256 payout = 1 * ppr / 100;
            epochEarnings[poolEpoch] += payout;
            uint256 liqAccessed = Lend(payable(controller.lender())).getLoanAmount(_nft, _id);
            totalPayout += ppr - payout - liqAccessed;
            if(liqAccessed == 0) {
                require(
                    this.getReservationsAvailable() > 0
                    , "NRA"
                );
            } else {
                reservations--;
            }
            closePoolContract.startAuction(ppr, _nft, _id);
            IERC721(_nft).transferFrom(msg.sender, address(closePoolContract), _id);
            emit NftClosed(
                adjustmentsRequired,
                closureNonce[_nft][_id],
                _nft,
                _id,
                msg.sender, 
                ppr, 
                address(closePoolContract)
            );
        }
        spotsRemoved += _nfts.length;
        require(
            token.transfer(msg.sender, totalPayout)
        );
        return(totalPayout);
    }

    /** 
        Error chart:
            IC - invalid caller
    */
    function updateSaleValue(
        bool gracePurchase,
        address _nft,
        uint256 _id,
        uint256 _saleValue
    ) external nonReentrant {
        require(
            msg.sender == address(closePoolContract)
            , "IC"
        );
        if(gracePurchase) {
            closureNegated[closureNonce[_nft][_id]][_nft][_id] = gracePurchase;
            spotsRemoved--;
            return;    
        }
        uint256 poolEpoch = epochOfClosure[closureNonce[_nft][_id]][_nft][_id];
        auctionSaleValue[closureNonce[_nft][_id]][_nft][_id] = _saleValue;
        if((payoutInfo[closureNonce[_nft][_id]][_nft][_id] >> 128) > _saleValue) {
            while(this.getTotalAvailableFunds(poolEpoch) > 0) {
                poolEpoch++;
            }
            if(poolEpoch > resetEpoch) {
                resetEpoch = poolEpoch;
            }
        } else {
            spotsRemoved--;
        }
    }

    /** 
    Error chart:
        AOG - auction is ongoing (can only restore with no auctions ongoing)
        NTY - not time yet (the current pool epoch is not yet at the allowed reset epoch) 
        RNN - restoration not needed (there is no need to restore the pool currently)
    */
    function restore() external nonReentrant {
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        require(
            closePoolContract.liveAuctions() == 0
            , "AOG"
        );
        require(
            poolEpoch >= resetEpoch
            , "NTY"
        );
        require(
            spotsRemoved != 0
            , "RNN"
        );
        delete spotsRemoved;
    }

    /* ======== ACCOUNT CLOSURE ======== */
    /**
    Error chart: 
        AA - already adjusted (this closure has already been adjusted for) 
        AU - adjustments up to date (no more adjustments currently needed for this position)
        AO - auction ongoing (there is a auction ongoing and adjustments can’t take place until the completion of an auction) 
        IAN - invalid adjustment nonce (check the NFT, ID, and closure nonce) 
    */
    function adjustTicketInfo(
        uint256 _nonce,
        address _nft,
        uint256 _id,
        uint256 _closureNonce
    ) external nonReentrant returns(uint256 payout) {
        require(
            !adjustCompleted[msg.sender][_nonce][_closureNonce][_nft][_id]
            , "AA"
        );
        require(
            adjustmentsMade[msg.sender][_nonce] < adjustmentsRequired
            , "AU"
        );
        require(
            Closure(payable(closePoolContract)).auctionComplete(
                _closureNonce, 
                _nft, 
                _id
            )
            , "AO"
        );
        Buyer storage trader = traderProfile[msg.sender][_nonce];
        require(trader.active);
        require(
            adjustmentsMade[msg.sender][_nonce] == adjustmentNonce[_nft][_id][_closureNonce] - 1
            , "IAN"
        );
        adjustmentsMade[msg.sender][_nonce]++;
        if(
            trader.unlockEpoch <= epochOfClosure[_closureNonce][_nft][_id]
            || trader.startEpoch > epochOfClosure[_closureNonce][_nft][_id]
            || closureNegated[_closureNonce][_nft][_id]
        ) {
            adjustCompleted[msg.sender][_nonce][_closureNonce][_nft][_id] = true;
            return 0;
        }
        uint256 epoch = epochOfClosure[_closureNonce][_nft][_id];
        payout = internalAdjustment(
            msg.sender,
            _nonce,
            payoutInfo[_closureNonce][_nft][_id],
            auctionSaleValue[_closureNonce][_nft][_id],
            trader.comListOfTickets,
            trader.comAmountPerTicket,
            epoch
        );
        emit PrincipalCalculated(
            address(closePoolContract),
            _nft,
            _id,
            msg.sender,
            _nonce,
            _closureNonce
        );
        adjustCompleted[msg.sender][_nonce][_closureNonce][_nft][_id] = true;
    }

    /**
        Error chart: 
            NA - not accredited
    */
    function processFees(uint256 _amount) external nonReentrant {
        require(
            controller.lender() == msg.sender
            , "NA"
        );
        uint256 poolEpoch = (block.timestamp - startTime) / epochLength;
        uint256 payout = _amount / 20;
        require(token.transfer(controller.multisig(), payout));
        epochEarnings[poolEpoch] += _amount - payout;
        emit FeesEarned(address(this), poolEpoch, _amount - payout);
    }

    /**
        Error chart: 
            NA - not accredited
            TNI - token not included in pool
            NLA - all available capital is borrowed
    */
    function accessLiq(
        address _user,
        uint256 _newLoanAmount,
        uint256 _amount
    ) external nonReentrant {
        require(
            controller.lender() == msg.sender
            , "NA"
        );
        require(_user != address(0));
        reservations += _newLoanAmount;
        require(token.transfer(_user, _amount));
    }

    /**
        Error chart: 
            NA - not accredited
    */
    function depositLiq(uint256 _closedLoanAmount) external nonReentrant {
        require(
            controller.lender() == msg.sender
            , "NA"
        );
        reservations -= _closedLoanAmount;
    }

    /**
        Error chart: 
            NA - not accredited
            NLE - no loan exists
    */
    function resetOutstanding(uint256 _closedLoanAmount) external nonReentrant {
        require(
            controller.lender() == msg.sender
            , "NA"
        );
        reservations -= _closedLoanAmount;
    }

    /* ======== INTERNAL ======== */
    function choppedPosition(
        address _buyer,
        uint256[] calldata tickets,
        uint256[] calldata amountPerTicket,
        uint256 startEpoch,
        uint256 finalEpoch
    ) internal returns(uint256 tempReturn) {
        uint256 _nonce = positionNonce[_buyer];
        positionNonce[_buyer]++;
        Buyer storage trader = traderProfile[_buyer][_nonce];
        adjustmentsMade[_buyer][_nonce] = adjustmentsRequired;
        trader.startEpoch = uint32(startEpoch);
        trader.unlockEpoch = uint32(finalEpoch);
        trader.active = true;
        uint256 riskPoints;
        uint256 length = tickets.length;
        for(uint256 i; i < length; i++) {
            if(tickets[i] > 100) {
                require(
                    (tickets[i]) * modTokenDecimal * ticketLimit 
                        < this.getPayoutPerReservation(startEpoch) * 50
                );
            }
            riskPoints += getSqrt(((riskBase + tickets[i]) / riskStep) ** 3) * amountPerTicket[i];
        }
        (trader.comListOfTickets, trader.comAmountPerTicket, tempReturn, trader.tokensLocked) = BitShift.bitShift(
            modTokenDecimal,
            tickets,
            amountPerTicket
        );
        trader.tokensStatic = trader.tokensLocked;
        if(startEpoch == (block.timestamp - startTime) / epochLength) {
            trader.riskStart = 
                uint32(
                    riskPoints * (epochLength - (block.timestamp - (startTime + startEpoch * epochLength)))
                        /  epochLength
                );
        } else {
            trader.riskStart = uint32(riskPoints);
        }
        tempReturn <<= 32;
        tempReturn |= trader.riskStart;
        trader.riskPoints = uint32(riskPoints);
        tempReturn <<= 32;
        tempReturn |= riskPoints;
        for(uint256 i; i < length; i++) {
            require(
                !nftClosed[startEpoch] || this.getTicketInfo(startEpoch, tickets[i]) == 0,
                "TC"
            );
        }

        emit Purchase(
            _buyer,
            tickets,
            amountPerTicket,
            _nonce,
            startEpoch,
            finalEpoch
        );
    }

    function updateProtocol(
        uint256 largestTicket,
        uint256 startEpoch,
        uint256 endEpoch,
        uint256[] calldata tickets, 
        uint256[] calldata ticketAmounts,
        uint256 riskPoints
    ) internal returns(uint256 totalTokens) {
        uint256 length = tickets.length;
        for(uint256 j = startEpoch; j < endEpoch; j++) {
            while(
                ticketsPurchased[j].length == 0 
                || ticketsPurchased[j].length - 1 < largestTicket / 10
            ) ticketsPurchased[j].push(0);
            uint256[] memory epochTickets = ticketsPurchased[j];
            uint256 amount;
            uint256 temp;
            for(uint256 i = 0; i < length; i++) {
                uint256 ticket = tickets[i];
                temp = this.getTicketInfo(j, ticket);
                temp += ticketAmounts[i];
                require(
                    ticketAmounts[i] != 0
                    , "ITA"
                );
                require(
                    temp <= amountNft * ticketLimit
                    , "TLE"
                );
                epochTickets[ticket / 10] &= ~((2**((ticket % 10 + 1)*25) - 1) 
                    - (2**(((ticket % 10))*25) - 1));
                epochTickets[ticket / 10] |= (temp << ((ticket % 10)*25));
                amount += ticketAmounts[i];
            }
            uint256 tempComp = compressedEpochVals[j];
            uint256 prevPosition;
            require(
                (
                    (compressedEpochVals[j] & (2**35 -1)) 
                    + amount
                ) < (2**35 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 35) - 1) - (2**prevPosition - 1)) 
                    | ((compressedEpochVals[j] & (2**35 -1)) + amount); 
            prevPosition += 35;
            require(
                (
                    ((compressedEpochVals[j] >> 35) & (2**51 -1)) 
                    + ((j == startEpoch ? riskPoints & (2**128 - 1) : riskPoints >> 128))
                ) < (2**51 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 51) - 1) - (2**prevPosition - 1)) 
                    | (
                        (
                            ((compressedEpochVals[j] >> 35) & (2**51 -1)) 
                            + (j == startEpoch ? riskPoints & (2**128 - 1) : riskPoints >> 128)
                        ) << prevPosition
                    );
            prevPosition += 135;
            require(
                (
                    ((compressedEpochVals[j] >> 170) & (2**84 -1)) 
                    + amount * modTokenDecimal
                ) < (2**84 -1)
            );
            tempComp = 
                tempComp & ~((2**(prevPosition + 84) - 1) - (2**prevPosition - 1)) 
                    | (
                        (
                            ((compressedEpochVals[j] >> 170) & (2**84 -1)) 
                            + amount * modTokenDecimal
                        ) << prevPosition
                    );
            compressedEpochVals[j] = tempComp;
            ticketsPurchased[j] = epochTickets;
            totalTokens = amount;
        }
    }

    function internalAdjustment(
        address _user,
        uint256 _nonce,
        uint256 _payout,
        uint256 _finalNftVal,
        uint256 _comTickets,
        uint256 _comAmounts,
        uint256 _epoch
    ) internal returns(uint256 payout) {
        Buyer storage trader = traderProfile[_user][_nonce];
        uint256 riskLost;
        uint256 tokensLost;
        uint256 appLoss;
        uint256 _riskParam = this.getUserRiskPoints(_user, _nonce, _epoch);
        _riskParam <<= 128;
        _riskParam |= trader.riskPoints;
        (
            payout,
            appLoss,
            riskLost,
            tokensLost
        ) = internalCalculation(
            _comTickets,
            _comAmounts,
            _epoch,
            _payout,
            _finalNftVal,
            _riskParam
        );
        appLoss += (appLoss % amountNft == 0 ? 0 : 1);
        if(trader.tokensLocked > appLoss) {
            trader.tokensLocked -= uint128(appLoss);
        } else {
            trader.tokensLocked = 0;
        }
        trader.riskLost += uint32(riskLost);
        trader.riskStartLost += uint32(trader.riskStart * riskLost / trader.riskPoints);
        trader.tokensLost += uint128(tokensLost);
        _payout >>= 128;
        if(_payout > _finalNftVal) {
            trader.tokensLocked -= uint128(payout);
        }
        require(token.transfer(_user, payout));
    }

    function internalCalculation(
        uint256 _comTickets,
        uint256 _comAmounts,
        uint256 _epoch,
        uint256 _payout,
        uint256 _finalNftVal,
        uint256 _riskParams
    ) internal view returns(
        uint256 payout,
        uint256 appLoss,
        uint256 riskLost,
        uint256 tokensLost
    ) {
        uint256 totalRiskPoints = _payout & (2**128 - 1);
        _payout >>= 128;
        while(_comAmounts > 0) {
            uint256 ticket = _comTickets & (2**25 - 1);
            uint256 amountTokens = _comAmounts & (2**25 - 1);
            uint256 totalTicketTokens = this.getTicketInfo(_epoch, ticket);
            uint256 payoutContribution = amountTokens * modTokenDecimal / amountNft / 100;
            if((ticket + 1) * modTokenDecimal * ticketLimit <= _finalNftVal) {
                if(_finalNftVal >= _payout) {
                    payout += 
                        (_finalNftVal - _payout) 
                            * findProperRisk(_riskParams, ticket, amountTokens) / totalRiskPoints;
                } else {
                    payout += payoutContribution;
                }
                delete amountTokens;
            } else if(ticket * modTokenDecimal * ticketLimit > _finalNftVal) {
                if(_finalNftVal >= _payout) {
                    tokensLost += 
                        (_finalNftVal - _payout) 
                            * findProperRisk(_riskParams, ticket, amountTokens) / totalRiskPoints;
                } 
                appLoss += payoutContribution;
            } else if(
                (ticket + 1) * modTokenDecimal * ticketLimit > _finalNftVal
            ) {
                if(
                    totalTicketTokens * modTokenDecimal / amountNft 
                        > (_finalNftVal - ticket * modTokenDecimal * ticketLimit)
                ) {
                    uint256 lossAmount;
                    lossAmount = (
                        totalTicketTokens * modTokenDecimal / amountNft 
                            - (_finalNftVal - ticket * modTokenDecimal * ticketLimit)
                    );
                    lossAmount = lossAmount * amountTokens / totalTicketTokens / 100;
                    appLoss += lossAmount;
                    if(_finalNftVal >= _payout) {
                        lossAmount *= 
                            (_finalNftVal - _payout) 
                                * findProperRisk(_riskParams, ticket, amountTokens) 
                                    / totalRiskPoints / payoutContribution;
                        tokensLost += lossAmount;
                        payout += 
                            (_finalNftVal - _payout) 
                                * findProperRisk(_riskParams, ticket, amountTokens) 
                                    / totalRiskPoints - lossAmount;
                    } else {
                        payout += payoutContribution - lossAmount;
                    }
                } else {
                    if(_finalNftVal >= _payout) {
                        payout += 
                            (_finalNftVal - _payout) 
                                * findProperRisk(_riskParams, ticket, amountTokens) 
                                    / totalRiskPoints;
                    } else {
                        payout += payoutContribution;
                    }
                    delete amountTokens;
                }
            }
            riskLost += findProperRisk(_riskParams, ticket, amountTokens) / amountNft;
            _comTickets >>= 25;
            _comAmounts >>= 25;
        }
    }

    function findProperRisk(
        uint256 _riskParams,
        uint256 _ticket,
        uint256 _amountTokens
    ) internal view returns(uint256 riskPoints) {
        return (_riskParams >> 128) * 
                    getSqrt(((riskBase + _ticket) / riskStep) ** 3) * _amountTokens / 100 / 
                        (_riskParams & (2**128 - 1));
    }

    /* ======== GETTER ======== */
    function getSqrt(uint x) public pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function getReservationsAvailable() external view returns(uint256) {
        return amountNft - reservations - spotsRemoved;
    }

    function getTotalAvailableFunds(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return (compVal >> 170) & (2**84 -1);
    }

    function getPayoutPerReservation(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return ((compVal >> 170) & (2**84 -1)) / amountNft;
    }

    function getRiskPoints(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return (compVal >> 35) & (2**51 -1);
    }

    function getTokensPurchased(uint256 _epoch) external view returns(uint256) {
        uint256 compVal = compressedEpochVals[_epoch];
        return compVal & (2**35 -1);
    }

    function getHeldTokenExistence(
        bytes32[] calldata _merkleProof, 
        address _nft, 
        uint256 _id
    ) external view returns(bool) {
        require(addressExists[_nft]);
        bytes memory id = bytes(Strings.toString(_id));
        uint256 nftInt = uint160(_nft);
        bytes memory nft = bytes(Strings.toString(nftInt));
        bytes memory value = bytes.concat(nft, id);
        bytes32 leaf = keccak256(abi.encodePacked(value));
        require(MerkleProof.verify(_merkleProof, root, leaf));
        return true;
    }

    function getTicketInfo(uint256 epoch, uint256 ticket) external view returns(uint256) {
        uint256[] memory epochTickets = ticketsPurchased[epoch];
        if(epochTickets.length <= ticket / 10) {
            return 0;
        }
        uint256 temp = epochTickets[ticket / 10];
        temp &= (2**((ticket % 10 + 1)*25) - 1) - (2**(((ticket % 10))*25) - 1);
        return temp >> ((ticket % 10) * 25);
    }

    function getUserRiskPoints(
        address _user, 
        uint256 _nonce,
        uint256 _epoch
    ) external view returns(uint256 riskPoints) {
        Buyer memory trader = traderProfile[_user][_nonce];
        if(_epoch == trader.startEpoch) {
            riskPoints = trader.riskStart;
        } else if(_epoch > trader.startEpoch && _epoch < trader.unlockEpoch){
            riskPoints = trader.riskPoints;
        }
    }
}