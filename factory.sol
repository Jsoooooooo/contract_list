// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./exchange.sol";

    error TOKEN_NOT_VALID();
error EXCHANGE_NOT_EXIST();
contract Factory {
    mapping(address=>address) public exchanges;

    function createExchange(address tokenAddress) external returns(address exchangeAddress){
        // 判断tokenAddress是否为空
        if (tokenAddress == address(0)) revert TOKEN_NOT_VALID();
        // 判断Exchange中是否有该token的market
        if (exchanges[tokenAddress] != address(0)) revert EXCHANGE_NOT_EXIST();

        Exchange exchange = new Exchange(tokenAddress);
        exchanges[tokenAddress] = address(exchange);
        exchangeAddress = address(exchange);
    }
    function getExchange(address tokenAddress) public view returns(address exchangeAddress){
        if (exchanges[tokenAddress] == address(0)) revert  EXCHANGE_NOT_EXIST();
        return exchanges[tokenAddress];
    }
}
