//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vault } from "./Vault.sol";
import { IVault } from "../abacusInterfaces/IVault.sol";
import { Closure } from "./Closure.sol";
import { AbacusController } from "./AbacusController.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "./ReentrancyGuard.sol";
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

/// @title Vault Factory
/// @author Gio Medici
/// @notice The factory is responsible for producing spot pools
contract Factory is ReentrancyGuard {

    /* ======== ADDRESS ======== */
    AbacusController public immutable controller;
    address private immutable _vaultMultiImplementation;
    address private immutable _closePoolImplementation;

    /* ======== MAPPING ======== */
    /// @notice ETH to be returned from all vaults is routed this mapping
    /// [address] -> User
    /// [uint256] -> Return amount 
    mapping(address => mapping(address => uint256)) public pendingReturns;

    /// @notice Track each pool using a unique multi asset mapping nonce
    /// [uint256] -> nonce
    mapping(string => SpotPool) public poolMapping;

    /* ======== MAPPING ======== */
    /// @notice Store information regarding a multi asset pool
    /// [slots] -> amount of NFTs that can be borrowed against at once
    /// [nftsInPool] -> total amount of NFTs linked to a pool
    /// [pool] -> pool address
    struct SpotPool {
        uint32 slots;
        address pool;
    }

    /* ======== EVENT ======== */
    event VaultCreated(string name, address _creator, address _pool);
    event PendingReturnsUpdated(address _user, address _token, uint256 _amount);
    event PendingReturnsClaimed(address _user, address _token, uint256 _amount);
    event NftToBytes(address _nft, uint256 _id, bytes returnValue);

    /* ======== MODIFIER ======== */
    modifier onlyAccredited {
        require(controller.accreditedAddresses(msg.sender), "Not accredited");
        _;
    }

    /* ======== CONSTRUCTOR ======== */
    constructor(address _controller) {
        _closePoolImplementation = address(new Closure());
        _vaultMultiImplementation = address(new Vault());
        controller = AbacusController(_controller);
    }

    /* ======== FALLBACK FUNCTIONS ======== */
    receive() external payable {}
    fallback() external payable {}

    /* ======== POOL CREATION ======== */
    /// SEE IFactory.sol FOR COMMENTS
    function initiateMultiAssetVault(
        string memory name
    ) external nonReentrant {
        require(bytes(name).length < 20);
        uint256 beta = controller.beta();
        if(beta == 1) {
            require(controller.userWhitelist(msg.sender), "You're not a WL creator for this phase.");
        }

        SpotPool storage pool = poolMapping[name];
        require(pool.pool == address(0));
        IVault vaultMultiDeployment = IVault(
            Clones.clone(_vaultMultiImplementation)
        );

        vaultMultiDeployment.initialize(
            name,
            address(controller),
            _closePoolImplementation,
            msg.sender
        );

        controller.addAccreditedAddressesMulti(address(vaultMultiDeployment));
        pool.pool = address(vaultMultiDeployment);
        emit VaultCreated(name, msg.sender, address(vaultMultiDeployment));
    }

    /* ======== CLAIMING RETURNED FUNDS/EARNED FEES ======== */
    /// SEE IFactory.sol FOR COMMENTS
    function updatePendingReturns(address _token, address _user, uint256 _amount) external nonReentrant {
        require(controller.accreditedAddresses(msg.sender), "NA");
        pendingReturns[_token][_user] += _amount;
        emit PendingReturnsUpdated(_user, _token, _amount);
    }

    /// SEE IFactory.sol FOR COMMENTS
    function claimPendingReturns(address[] calldata _token) external nonReentrant {
        uint256 length = _token.length;
        for(uint256 i; i < length; i++) {
            address token = _token[i];
            uint256 payout = pendingReturns[token][msg.sender];
            delete pendingReturns[token][msg.sender];
            ERC20(token).transfer(msg.sender, payout);
            emit PendingReturnsClaimed(msg.sender, token, payout);
        }
    }
    
    /* ======== GETTERS ======== */
    function getPoolAddress(string memory name) external view returns(address) {
        return poolMapping[name].pool;
    }

    function getDecodedCompressedTickets(
        uint256 comTickets
    ) external pure returns(
        uint256 stopIndex,
        uint256[10] memory tickets 
    ) {
        uint256 i;
        uint256 tracker = 1;
        while(tracker > 0) {
            tracker = comTickets;
            uint256 ticket = comTickets & (2**25 - 1);
            comTickets >>= 25;

            if(tracker != 0) {
                tickets[i] = ticket;
            } else {
                stopIndex = i;
            }
            i++;
        }
    }

    function getBytes(address _nft, uint256 _id) public returns (bytes memory){
        bytes memory id = bytes(Strings.toString(_id));
        uint256 nftInt = uint160(_nft);
        bytes memory nft = bytes(Strings.toString(nftInt));
        bytes memory value = bytes.concat(nft, id);
        emit NftToBytes(_nft, _id, value);
        return value;
    }
}