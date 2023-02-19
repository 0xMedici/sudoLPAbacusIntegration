//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ProofCheck {

    function proofCheck(
        bytes32[] calldata _merkleProof, 
        bytes32 root, 
        address _nft, 
        uint256 _id
    ) external pure returns(bool) {
        bytes memory id = bytes(Strings.toString(_id));
        uint256 nftInt = uint160(_nft);
        bytes memory nft = bytes(Strings.toString(nftInt));
        bytes memory value = bytes.concat(nft, id);
        bytes32 leaf = keccak256(abi.encodePacked(value));
        require(MerkleProof.verify(_merkleProof, root, leaf));
        return true;
    }
}