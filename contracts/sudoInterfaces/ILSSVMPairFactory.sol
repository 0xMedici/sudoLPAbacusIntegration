//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ICurve } from "./ICurve.sol";
import { LSSVMPair } from "../sudoHelpers/LSSVMPair.sol";
import { LSSVMPairETH } from "../sudoHelpers/LSSVMPairETH.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ILSSVMPairFactory {

    function createPairETH(
        IERC721 _nft,
        ICurve _bondingCurve,
        address payable _assetRecipient,
        LSSVMPair.PoolType _poolType,
        uint128 _delta,
        uint96 _fee,
        uint128 _spotPrice,
        uint256[] calldata _initialNFTIDs
    ) external payable returns (LSSVMPairETH pair);

    function depositNFTs(
        IERC721 _nft,
        uint256[] calldata ids,
        address recipient
    ) external;
}