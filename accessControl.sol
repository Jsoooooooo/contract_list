// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

error NOT_AUTHORED();

contract accessControl {
    event GrantRole(bytes32 indexed role,address indexed account);
    event RevokeRole(bytes32 indexed role,address indexed account);

    // role => account => bool
    mapping(bytes32 => mapping(address=>bool)) public roles;

    bytes private constant ADMIN = keccak256(abi.encodePacked('ADMIN'));

    constructor (){
        _grantRole(ADMIN,msg.sender);
    }
    modifier onlyRole(bytes32 _role){
        if (!roles[_role][msg.sender]) revert NOT_AUTHORED();
        _;
    }
    function _grantRole(bytes32 _role,address _account) internal {
        roles[_role][_account] =true;
        emit GrantRole(_role,_account);
    }
    // give role to an account
    function grantRole(bytes32 _role,address _account)
    onlyRole(ADMIN) // only admin can call this function
    external {
        _grantRole(_role,_account);
    }

    function revokeRole(bytes32 _role,address _account)
    onlyRole(ADMIN)
    external {
        roles[_role][_account] = false;
        emit RevokeRole(_role,_account);
    }
}
