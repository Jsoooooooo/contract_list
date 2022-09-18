// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract hashFunc {
    function hashFunc(string memory text,uint256 num,address _addrress) external pure returns(bytes32){
        return keccak256(abi.encodePacked(text,num,_addrress));
    }
}
