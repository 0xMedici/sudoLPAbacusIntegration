//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

contract Bytes { 

    function getBytes(address _nft, uint256 _id) public pure returns (bytes memory){
        bytes memory id = bytes(Strings.toString(_id));
        uint256 nftInt = uint160(_nft);
        bytes memory nft = bytes(Strings.toString(nftInt));
        bytes memory value = bytes.concat(nft, id);
        return value;
    }
}