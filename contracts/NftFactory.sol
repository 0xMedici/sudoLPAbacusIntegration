// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import { SudoNft } from "./SudoNFT.sol";

contract NftFactory {

    address public admin;
    address public abacusController;
    address public sudoFactoryAddress;

    mapping(address => bool) public whitelistedCreators;
    mapping(address => address) public sudoNfts;

    event SudoNFTCreated(address sudoNft);

    constructor(
        address _admin,
        address _controller,
        address _factoryAddress
    ) {
        admin = _admin;
        sudoFactoryAddress = _factoryAddress;
        abacusController = _controller;
    }

    function whitelistCreator(address[] calldata _user) external {
        require(msg.sender == admin, "Not admin");
        for(uint256 i = 0; i < _user.length; i++) {
            whitelistedCreators[_user[i]] = true;
        }
    }

    function createSudoNFT(
        address _collection,
        uint256 _maxLPTokens
    ) external {
        require(
            whitelistedCreators[msg.sender]
            , "Not whitelisted"
        );
        require(
            sudoNfts[_collection] == address(0)
            , "Collection already has pool"
        );
        SudoNft sudoNft = new SudoNft(
            admin,
            abacusController,
            sudoFactoryAddress,
            _collection,
            _maxLPTokens
        );

        sudoNfts[_collection] = address(sudoNft);
        emit SudoNFTCreated(
            address(sudoNft)
        );
    }
}