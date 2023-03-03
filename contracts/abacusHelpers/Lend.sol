//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";
import { Closure } from "./Closure.sol";
import { AbacusController } from "./AbacusController.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IWETH } from "../abacusInterfaces/IWETH.sol";

import "./ReentrancyGuard.sol";
import "hardhat/console.sol";

/// @title NFT Lender
/// @author Gio Medici
/// @notice Borrow against the value of a backing Abacus Spot pool
contract Lend is ReentrancyGuard {

    /* ======== ADDRESS IMMUTABLE ======== */
    AbacusController public immutable controller;
    address public WETH;

    /* ======== MAPPING ======== */
    /// @notice Track if a loan has been taken out against an NFT
    /// [address] -> NFT Collection address
    /// [uint256] -> NFT ID
    /// [bool] -> deployment status
    mapping(address => mapping(uint256 => bool)) public loanDeployed;

    /// @notice Track loan metrics
    /// [address] -> NFT Collection address
    /// [uint256] -> NFT ID
    mapping(address => mapping(uint256 => Position)) public loans;
    
    /* ======== STRUCT ======== */
    /// @notice Struct to hold information regarding deployed loan
    /// [borrower] -> User with the borrower
    /// [pool] -> Underlying Spot pool
    /// [transferFromPermission] -> Stores the address of a user with transfer permission
    /// [startEpoch] -> The epoch that the loan was taken out
    /// [amount] -> Outstanding loan amount
    /// [timesInterestPaid] -> Amout of epochs that interest has been paid
    /// [interestPaid] -> Track whether a loan has had interest paid during an epoch
        /// [uint256] -> epoch
    struct Position {
        address borrower;
        address pool;
        address transferFromPermission;
        uint256 startEpoch;
        uint256 amount;
        uint256 interestEpoch;
    }

    /* ======== EVENT ======== */
    event EthBorrowed(address _user, address _pool, address[] nft, uint256[] id, uint256[] _amount);
    event InterestPaid(address _user, address _pool, address[] nft, uint256[] id);
    event EthRepayed(address _user, address _pool, address[] nft, uint256[] id, uint256[] _amount);
    event BorrowerLiquidated(address _user, address _pool, address nft, uint256 id, uint256 _amount);
    event LoanTransferred(address _pool, address from, address to, address nft, uint256 id);

    /* ======== CONSTRUCTOR ======== */
    constructor(address _controller, address weth) {
        controller = AbacusController(_controller);
        WETH = weth;
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== LENDING ======== */
    /// SEE ILend.sol FOR COMMENTS
    function borrow(
        address _pool,
        bytes32[][] calldata _merkleProofs, 
        address[] calldata _nfts, 
        uint256[] calldata _ids, 
        uint256[] calldata _amounts
    ) external nonReentrant {
        uint256 length = _nfts.length;
        uint256 newLoans;
        uint256 totalAmount;
        require(controller.accreditedAddresses(_pool), "Not accredited");
        Vault vault = Vault(payable(_pool));
        for(uint256 j = 0; j < _nfts.length; j++) {
            require(
                vault.getHeldTokenExistence(_merkleProofs[j], _nfts[j], _ids[j])
                , "Invalid borrow choice"
            );
            if(loanDeployed[_nfts[j]][_ids[j]]) {
                require(
                    loans[_nfts[j]][_ids[j]].pool == _pool
                    , "Incorrect pool input"    
                );
            }
        }
        for(uint256 i = 0; i < length; i++) {
            address _nft = _nfts[i];
            uint256 _id = _ids[i];
            uint256 _amount = _amounts[i];
            require(_amount > 0, "Must borrow some amount");
            Position storage openLoan = loans[_nft][_id];
            uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
            require(
                msg.sender == ERC721(_nft).ownerOf(_id)
                || msg.sender == openLoan.borrower
                , "Not owner"
            );
            if(openLoan.amount == 0) {
                require(
                    vault.getReservationsAvailable() > 0
                    , "Unable to take out a new loan right now. All Collateral Slots in use."
                );
                IERC721(_nft).transferFrom(msg.sender, address(this), _id);
                newLoans++;
            }
            require(
                95 * vault.getPayoutPerReservation((block.timestamp - vault.startTime()) / vault.epochLength()) 
                    / 100 >= (_amount + openLoan.amount)
                , "Exceed current LTV"
            );
            uint256 payoutPerResFuture = 
                vault.getPayoutPerReservation(
                    (block.timestamp - vault.startTime() + vault.epochLength() / 6) / vault.epochLength()
                );
            require(
                95 * payoutPerResFuture / 100 >= _amount + openLoan.amount
                , "Exceed future LTV"
            );
            if(!loanDeployed[_nft][_id]) {
                openLoan.pool = address(vault);
                openLoan.amount = _amount;
                openLoan.borrower = msg.sender;
                openLoan.startEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
                openLoan.interestEpoch = openLoan.startEpoch;
                loanDeployed[_nft][_id] = true;
            } else {
                if(poolEpoch > openLoan.interestEpoch) {
                    uint256 epochsMissed = poolEpoch + 1 - openLoan.interestEpoch;
                    require(
                        epochsMissed == 0
                        , "Must pay down interest owed before borrowing more"
                    );    
                }
                openLoan.amount += _amount;
            }
            require(
                IERC721(_nft).ownerOf(_id) == address(this)
                , "NFT custody transfer failed"
            );
            totalAmount += _amount;
        }
        vault.accessLiq(msg.sender, newLoans, totalAmount);
        emit EthBorrowed(msg.sender, _pool, _nfts, _ids, _amounts);
    }

    function payInterest(
        address _pool,
        address[] calldata _nfts, 
        uint256[] calldata _ids
    ) external nonReentrant {
        uint256 totalInterest = _payInterest(msg.sender, _pool, _nfts, _ids);
        require((Vault(_pool).token()).transferFrom(msg.sender, _pool, totalInterest));
    }

    /// SEE ILend.sol FOR COMMENTS
    function payInterestETH(
        address _pool,
        address[] calldata _nfts, 
        uint256[] calldata _ids
    ) external payable nonReentrant {
        // address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        uint256 totalInterest = _payInterest(msg.sender, _pool, _nfts, _ids);
        require(address(Vault(_pool).token()) == WETH, "Pool does not use WETH");
        require(msg.value >= totalInterest, "Incorrect ETH amount");
        uint256 returnAmount = msg.value - totalInterest;
        IWETH(WETH).deposit{value: totalInterest}();
        require(Vault(_pool).token().transfer(_pool, totalInterest));
        payable(msg.sender).transfer(returnAmount);
    }

    function repay(
        address _pool,
        address[] calldata _nfts,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external {
        (uint256 totalFees, uint256 repayAmount) = _repay(msg.sender, _pool, _nfts, _ids, _amounts);
        require(Vault(_pool).token().transferFrom(msg.sender, _pool, totalFees + repayAmount));
    }

    function repayETH(
        address _pool,
        address[] calldata _nfts,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external payable nonReentrant {
        // address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        (uint256 totalFees, uint256 repayAmount) = _repay(msg.sender, _pool, _nfts, _ids, _amounts);
        require(address(Vault(_pool).token()) == WETH, "Pool does not use WETH");
        require(msg.value >= totalFees + repayAmount, "Incorrect ETH amount");
        uint256 returnAmount = msg.value - totalFees - repayAmount;
        IWETH(WETH).deposit{value: totalFees + repayAmount}();
        require(Vault(_pool).token().transfer(_pool, totalFees + repayAmount));
        payable(msg.sender).transfer(returnAmount);
    }

    /// SEE ILend.sol FOR COMMENTS
    function liquidate(
        bytes32[][] calldata _merkleProofs,
        address[] calldata _nfts, 
        uint256[] calldata _ids
    ) external nonReentrant {
        Vault vault = Vault(payable(loans[_nfts[0]][_ids[0]].pool));
        uint256 length = _nfts.length;
        for(uint256 i = 0; i < length; i++) {
            require(
                address(vault) == loans[_nfts[i]][_ids[i]].pool
                , "Pools must be the same"
            );
            uint256 loanAmount = loans[_nfts[i]][_ids[i]].amount;
            uint256 futureEpoch = 
                (
                    block.timestamp - vault.startTime() 
                        + vault.epochLength() / 6
                ) / vault.epochLength();
            require(
                loanAmount > vault.getPayoutPerReservation(futureEpoch)
                , "Liquidation failed"
            );
            emit BorrowerLiquidated(
                loans[_nfts[i]][_ids[i]].borrower, 
                address(vault), 
                _nfts[i], 
                _ids[i], 
                loanAmount
            );
        }
        _processLiquidation(
            vault, 
            _merkleProofs,
            _nfts,
            _ids
        );
        for(uint256 i = 0; i < length; i++) {
            delete loanDeployed[_nfts[i]][_ids[i]];
            delete loans[_nfts[i]][_ids[i]];
        }
    }

    function liquidateLate(
        address _nft, 
        uint256 _id
    ) external nonReentrant {
        Vault vault = Vault(payable(loans[_nft][_id].pool));
        uint256 loanAmount = loans[_nft][_id].amount;
        delete loanDeployed[_nft][_id];
        delete loans[_nft][_id];
        uint256 currentEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        require(
            loanAmount > vault.getPayoutPerReservation(currentEpoch)
            , "Liquidation failed"
        );
        require(
            (vault.token()).transferFrom(msg.sender, address(vault), loanAmount)
            , "Must cover entire loan"
        );
        IERC721(_nft).transferFrom(address(this), msg.sender, _id);
        vault.resetOutstanding(1);
    }

    /// SEE ILend.sol FOR COMMENTS
    function allowTransferFrom(address nft, uint256 id, address allowee) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(
            msg.sender == openLoan.borrower
            , "Not borrower"
        );
        openLoan.transferFromPermission = allowee;
    }

    /// SEE ILend.sol FOR COMMENTS
    function transferFromLoanOwnership(
        address from,
        address to, 
        address nft, 
        uint256 id
    ) external nonReentrant {
        Position storage openLoan = loans[nft][id];
        require(
            msg.sender == openLoan.borrower
            || openLoan.transferFromPermission == msg.sender
            , "No permission"
        );
        delete openLoan.transferFromPermission;
        openLoan.borrower = to;
        emit LoanTransferred(openLoan.pool, from, to, nft, id);
    }
    
    /* ======== INTERNAL ======== */
    function _payInterest(
        address _user,
        address _pool,
        address[] calldata _nfts, 
        uint256[] calldata _ids
    ) internal returns(uint256 totalInterest){
        Vault vault = Vault(payable(_pool));
        for(uint256 i = 0; i < _nfts.length; i++) {
            Position storage openLoan = loans[_nfts[i]][_ids[i]];
            require(
                openLoan.pool == _pool
                , "Incorrect pool input"    
            );
            require(
                openLoan.amount != 0
                , "No open loan"
            );
            uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
            require(
                poolEpoch + 1 != openLoan.interestEpoch
                , "Interest already paid"
            );
            uint256 interestEpoch_ = openLoan.interestEpoch;
            for(uint256 j = interestEpoch_; j < poolEpoch; j++) {
                totalInterest += vault.interestRate() * vault.getPayoutPerReservation(j) / 10_000 
                            * vault.epochLength() / (52 weeks);
                interestEpoch_++;
            }
            openLoan.interestEpoch = interestEpoch_;
        }
        vault.processFees(totalInterest);
        emit InterestPaid(_user, _pool, _nfts, _ids);
    }

    function _repay(
        address _user,
        address _pool,
        address[] calldata _nfts,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) internal returns(uint256 totalFees, uint256 repayAmount) {
        uint256 closedLoans;
        Vault vault = Vault(_pool);
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        for(uint256 i = 0; i < _nfts.length; i++) {
            Position storage openLoan = loans[_nfts[i]][_ids[i]];
            require(
                openLoan.amount != 0
                , "No open loan"
            );
            require(
                msg.sender == openLoan.borrower
                , "Not borrower"
            );
            if(
                poolEpoch == openLoan.interestEpoch
                && _amounts[i] == openLoan.amount
            ) {
                totalFees += vault.interestRate() * vault.getPayoutPerReservation(poolEpoch) / 10_000 
                            * vault.epochLength() / (52 weeks);
                openLoan.interestEpoch++;
            } else {
                require(
                    poolEpoch + 1 == openLoan.interestEpoch
                    , "Must pay outstanding interest"
                );
            }
            repayAmount += _amounts[i];
            openLoan.amount -= _amounts[i];
            if(openLoan.amount == 0) {
                closedLoans++;
                _closeLoan(_user, _nfts[i], _ids[i]);
            }
        }
        vault.processFees(totalFees);
        vault.depositLiq(closedLoans);
        emit EthRepayed(_user, _pool, _nfts, _ids, _amounts);
    }

    function _closeLoan(address _user, address _nft, uint256 _id) internal {
        delete loans[_nft][_id];
        delete loanDeployed[_nft][_id];
        IERC721(_nft).transferFrom(address(this), _user, _id);
        require(
            IERC721(_nft).ownerOf(_id) == _user
            , "Transfer failed"
        );
    }

    function _processLiquidation(
        Vault vault,
        bytes32[][] calldata _merkleProofs,
        address[] calldata _nfts,
        uint256[] calldata _ids
    ) internal {
        IERC721(_nfts[0]).setApprovalForAll(address(vault), true);
        uint256 payout = vault.closeNft(_merkleProofs, _nfts, _ids);
        require(
            (vault.token()).transfer(msg.sender, payout / 10)
            , "Transfer to liquidator failed"
        );
        require(
            (vault.token()).transfer(
                address(vault),
                payout - payout / 10
            )
            , "Transfer to vault failed"
        );
        vault.processFees(payout - payout / 10);
    }

    /* ======== GETTERS ======== */
    /// SEE ILend.sol FOR COMMENTS
    function getLoanAmount(
        address nft, 
        uint256 id
    ) external view returns(
        uint256 loanAmount
    ) {
        if(loanDeployed[nft][id]) {
            loanAmount = loans[nft][id].amount;    
        } else {
            return 0;
        }
    }

    /// SEE ILend.sol FOR COMMENTS
    function getInterestPayment(address _pool, address[] calldata _nfts, uint256[] calldata _ids) external view returns(uint256) {
        Vault vault = Vault(payable(_pool));
        uint256 totalInterest;
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        for(uint256 i = 0; i < _nfts.length; i++) {
            Position storage openLoan = loans[_nfts[i]][_ids[i]];
            if(
                openLoan.amount == 0
                || openLoan.interestEpoch == poolEpoch + 1
            ) {
                return 0;
            }
            for(uint256 j = openLoan.interestEpoch; j < poolEpoch; j++) {
                totalInterest += vault.interestRate() * vault.getPayoutPerReservation(j) / 10_000 
                            * vault.epochLength() / (52 weeks);
            }
        }
        return totalInterest;
    }

    function getRepaymentAmount(
        address _pool,
        address[] calldata _nfts,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external view returns(uint256 repayAmount) {
        Vault vault = Vault(_pool);
        uint256 poolEpoch = (block.timestamp - vault.startTime()) / vault.epochLength();
        for(uint256 i = 0; i < _nfts.length; i++) {
            Position memory openLoan = loans[_nfts[i]][_ids[i]];
            require(
                openLoan.amount != 0
                , "No open loan"
            );
            if(
                poolEpoch == openLoan.interestEpoch
                && _amounts[i] == openLoan.amount
            ) {
                repayAmount += vault.interestRate() * vault.getPayoutPerReservation(poolEpoch) / 10_000 
                            * vault.epochLength() / (52 weeks);
            }
            repayAmount += _amounts[i];
        }
    }
}