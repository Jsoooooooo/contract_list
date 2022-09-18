// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error TransferFailed();
error Not_Enough_Fund();
error Not_Enough_Token_Fo_rBorrow();
error Account_Cant_Liquidated();
error Choose_Other_Repay_Token();
error NeedsMoreThanZero();
error TokenNotAllowed(address token);
contract lending is  ReentrancyGuard, Ownable {

    address[] public s_allowedTokens;
    mapping(address=>address) public s_tokenToPriceFeed;

    // account address => token address  => amount
    mapping(address =>mapping(address=>uint256)) public s_accountToTokenDeposits;
    // token address => account address => amount
    mapping(address=>mapping(address=>uint256)) public s_accountToTokenBorrows;

    // 5% Liquidation Reward
    uint256 public constant LIQUIDATION_REWARD = 5;
    // At 80% Loan to Value Ratio, the loan can be liquidated
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    event Deposit(address indexed account,address indexed token,uint256 indexed amount);
    event Withdraw(address indexed account,address indexed token,uint256 indexed amount);
    event Borrow(address indexed account,address indexed token,uint256 indexed amount);
    event Repay(address indexed account,address indexed token,uint256 indexed amount);
    event Liquidate(
        address indexed account,
        address indexed repayToken,
        address indexed rewardToken,
        uint256 halfDebtInEth,
        address liquidator
    );

    // deposit token to the contract
    function deposit(address token,uint256 amount)
    nonReentrant
    isAllowedToken(token)
    moreThanZero(amount)
    external {
        emit Deposit(msg.sender,token,amount);
        s_accountToTokenDeposits[msg.sender][token] += amount;
        bool success = IERC20(token).transferFrom(msg.sender,address(this),amount);
        if (!success) revert TransferFailed();
    }

    // withdraw token from contract
    function withdraw(address token,uint256 amount)
    isAllowedToken(token)
    moreThanZero(amount)
    nonReentrant
    external {
        // 如果withdraw的amount大于deposit的amount
        if (amount >= s_accountToTokenDeposits[msg.sender][token]){revert Not_Enough_Fund();}
        emit Withdraw(msg.sender,token,amount);
        _transferFunds(msg.sender, token, amount);
    }

    // the transfer function that called for transfering purposes
    // 向msg.sender转钱
    function _transferFunds(address account,address token, uint256 amount) private {
        if (amount >= s_accountToTokenDeposits[msg.sender][token]){revert Not_Enough_Fund();}
        s_accountToTokenDeposits[account][token] -= amount;
        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    function borrow(address token,uint256 amount)
    isAllowedToken(token)
    moreThanZero(amount)
    nonReentrant
    external{
        // 如果本地址拥有token的amount小于用户要借的amount
        if (IERC20(token).balanceOf(address(this))<amount){revert Not_Enough_Token_Fo_rBorrow();}
        // msg.sender的借款增加
        s_accountToTokenBorrows[msg.sender][token] += amount;
        emit Borrow(msg.sender, token, amount);
        // 合约像msg.sender 转移对应的amount
        bool success = IERC20(token).transfer(msg.sender,amount);
        if (!success) revert TransferFailed();
        // 写完回来看
    }

    function repay(address token,uint256 amount)
    isAllowedToken(token)
    moreThanZero(amount)
    nonReentrant
    external
    {
        emit Repay(msg.sender, token, amount);
        // 调用private repay function
        _repay(msg.sender, token, amount);
    }

    function _repay(address account,address token,uint256 amount) private {
        // msg.sender借款减少相应的amount
        s_accountToTokenBorrows[account][token] -= amount;
        // 通过调用transferFrom,让钱回流到合约
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
    }

    function liquidate(
        address account,
        address repayToken,
        address rewardToken
    ) external nonReentrant{
        // 如果账户的health情况大于最坏情况，则账户不能被清算
        if (healthFactor(msg.sender) > MIN_HEALTH_FACTOR) revert Account_Cant_Liquidated();
        // 帮助解决一半的烂账，并计算以ETH为计价单位的值
        uint256 halfDebt = s_accountToTokenBorrows[account][repayToken] / 2;
        uint256 halfDebtInEth = getEthValue(repayToken, halfDebt);
        // 如果
        if (halfDebtInEth<0) revert Choose_Other_Repay_Token();
        // 计算清算获得的奖励
        uint256 rewardAmountInEth = (halfDebtInEth * LIQUIDATION_REWARD) / 100;
        //货币转换
        uint256 totalRewardAmountInRewardToken = getTokenValueFromEth(
            rewardToken,
            rewardAmountInEth + halfDebtInEth
        );
        _repay(account, repayToken, halfDebt);
        _transferFunds(account, rewardToken, totalRewardAmountInRewardToken);
    }
    function getAccountInformation(address user)
    public
    view
    returns (uint256 borrowedValueInETH, uint256 collateralValueInETH)
    {
        borrowedValueInETH = getAccountBorrowedValue(user);
        collateralValueInETH = getAccountCollateralValue(user);
    }

    // 循环allowedToken，获取用户每一个token的deposit信息，并加总
    function getAccountCollateralValue(address user) public view returns(uint256){
        uint256 totalCollateralValueInETH = 0;
        for (uint256 index=0;index<s_allowedTokens.length;index++){
            address token = s_allowedTokens[index];
            uint256 amount = s_accountToTokenDeposits[user][token];
            uint256 valueInEth = getEthValue(token, amount);
            totalCollateralValueInETH += valueInEth;
        }
        return totalCollateralValueInETH;
    }

    // 循环allowedToken，获取用户每一个token的borrow信息，并加总
    function getAccountBorrowedValue(address user) public view returns (uint256){
        uint256 totalBorrowValueInETH = 0;
        for (uint256 index=0;index<s_allowedTokens.length;index++){
            address token = s_allowedTokens[index];
            uint256 amount = s_accountToTokenBorrows[user][token];
            uint256 valueInEth = getEthValue(token, amount);
            totalBorrowValueInETH += valueInEth;
        }
        return totalBorrowValueInETH;
    }

    // token值以ETH计价
    function getEthValue(address token, uint256 amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // 2000 DAI = 1 ETH
        // 0.002 ETH per DAI
        // price will be something like 20000000000000000
        // So we multiply the price by the amount, and then divide by 1e18
        // 2000 DAI * (0.002 ETH / 1 DAI) = 0.002 ETH
        // (2000 * 10 ** 18) * ((0.002 * 10 ** 18) / 10 ** 18) = 0.002 ETH
        return (uint256(price) * amount) / 1e18;
    }

    // ETH转为以token值计价
    function getTokenValueFromEth(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (amount * 1e18) / uint256(price);
    }

    function healthFactor(address account) public view returns (uint256) {
        (uint256 borrowedValueInEth, uint256 collateralValueInEth) = getAccountInformation(account);
        uint256 collateralAdjustedForThreshold = (collateralValueInEth * LIQUIDATION_THRESHOLD) / 100;
        // 如果没有borrow，就返回100e18
        if (borrowedValueInEth == 0) return 100e18;
        // 如果borrow了，返回抵押值/借贷值的比
        return (collateralAdjustedForThreshold * 1e18) / borrowedValueInEth;
    }

    /********************/
    /* Modifiers */
    /********************/
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert NeedsMoreThanZero();
        }
        _;
    }
    modifier isAllowedToken(address token) {
        if (s_tokenToPriceFeed[token] == address(0)) revert TokenNotAllowed(token);
        _;
    }
}
