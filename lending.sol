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
        // ??????withdraw???amount??????deposit???amount
        if (amount >= s_accountToTokenDeposits[msg.sender][token]){revert Not_Enough_Fund();}
        emit Withdraw(msg.sender,token,amount);
        _transferFunds(msg.sender, token, amount);
    }

    // the transfer function that called for transfering purposes
    // ???msg.sender??????
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
        // ?????????????????????token???amount?????????????????????amount
        if (IERC20(token).balanceOf(address(this))<amount){revert Not_Enough_Token_Fo_rBorrow();}
        // msg.sender???????????????
        s_accountToTokenBorrows[msg.sender][token] += amount;
        emit Borrow(msg.sender, token, amount);
        // ?????????msg.sender ???????????????amount
        bool success = IERC20(token).transfer(msg.sender,amount);
        if (!success) revert TransferFailed();
        // ???????????????
    }

    function repay(address token,uint256 amount)
    isAllowedToken(token)
    moreThanZero(amount)
    nonReentrant
    external
    {
        emit Repay(msg.sender, token, amount);
        // ??????private repay function
        _repay(msg.sender, token, amount);
    }

    function _repay(address account,address token,uint256 amount) private {
        // msg.sender?????????????????????amount
        s_accountToTokenBorrows[account][token] -= amount;
        // ????????????transferFrom,?????????????????????
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
    }

    function liquidate(
        address account,
        address repayToken,
        address rewardToken
    ) external nonReentrant{
        // ???????????????health???????????????????????????????????????????????????
        if (healthFactor(msg.sender) > MIN_HEALTH_FACTOR) revert Account_Cant_Liquidated();
        // ??????????????????????????????????????????ETH?????????????????????
        uint256 halfDebt = s_accountToTokenBorrows[account][repayToken] / 2;
        uint256 halfDebtInEth = getEthValue(repayToken, halfDebt);
        // ??????
        if (halfDebtInEth<0) revert Choose_Other_Repay_Token();
        // ???????????????????????????
        uint256 rewardAmountInEth = (halfDebtInEth * LIQUIDATION_REWARD) / 100;
        //????????????
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

    // ??????allowedToken????????????????????????token???deposit??????????????????
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

    // ??????allowedToken????????????????????????token???borrow??????????????????
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

    // token??????ETH??????
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

    // ETH?????????token?????????
    function getTokenValueFromEth(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (amount * 1e18) / uint256(price);
    }

    function healthFactor(address account) public view returns (uint256) {
        (uint256 borrowedValueInEth, uint256 collateralValueInEth) = getAccountInformation(account);
        uint256 collateralAdjustedForThreshold = (collateralValueInEth * LIQUIDATION_THRESHOLD) / 100;
        // ????????????borrow????????????100e18
        if (borrowedValueInEth == 0) return 100e18;
        // ??????borrow?????????????????????/???????????????
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
