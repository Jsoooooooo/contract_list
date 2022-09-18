pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error NOT_ENOUGH_TOKEN();
error NEED_FREQUENCY();
error Plan_NOT_EXIST();
error SUBSCRIPTION_NOT_EXIST();

contract Subscription {
    uint256 public nextPlanId;
    struct Plan {
        address merchant;
        address token;
        uint256 amount;
        uint256 frequency;
    }
    struct Subscription {
        address subscriber;
        uint256 start; // date start of subscription
        uint256 nextPayment;
    }
    mapping(uint256=>Plan) public plans;
    // address of subscriber => uint256 => Subscription
    mapping(address=>mapping(uint256=>Subscription)) public subscriptions;

    //////////////////
    event PlanCreated(address indexed account,address indexed token, uint256 amount,uint256 frequency);
    event PaymentStatement(address indexed buyer,address indexed merchant, uint256 amount,uint256 indexed planId,uint timeStamp);
    event SubscriptionCreated(address indexed buyer,uint256 indexed planId,uint timeStamp);
    event PaymentSent(address indexed buyer,address indexed receiver,uint256 amount,uint256 planId, uint timeStamp);
    event SubscriptionCanceled(address indexed buyer,uint256 indexed planId,uint timeStamp);
    //////////////////

    function creatSubscription(address token,uint256 amount,uint256 frequency) external {
        if (amount <=0) revert NOT_ENOUGH_TOKEN();
        if (frequency <= 0) revert NEED_FREQUENCY();
        plans[nextPlanId] = Plan(msg.sender,token,amount,frequency);
        emit PlanCreated(msg.sender,token,amount,frequency);
        nextPlanId ++;
    }

    function Subscribe(uint256 planId) external {
        IERC20 token = IERC20(plans[planId].token);
        Plan storage plan = plans[planId];
        if (plan.merchant == address(0)) revert Plan_NOT_EXIST();
        token.transferFrom(msg.sender,address(this),plan.amount);
        emit PaymentStatement(msg.sender,plan.merchant,plan.amount,planId,block.timestamp);

        subscriptions[msg.sender][planId] = Subscription(msg.sender,block.timestamp,block.timestamp+plan.frequency);
        emit SubscriptionCreated(msg.sender,planId,block.timestamp);
    }

    function cancel(uint256 planId) external {
        Subscription storage subscription = subscriptions[msg.sender][planId];
        if (subscription.subscriber == address(0)) revert SUBSCRIPTION_NOT_EXIST();
        delete subscriptions[msg.sender][planId];
        emit SubscriptionCanceled(msg.sender,planId,block.timestamp);
    }

    function pay(address subscriber,uint256 planId) external {
        Subscription storage subscription = subscriptions[subscriber][planId];
        Plan storage plan = plans[planId];
        IERC20 token = IERC20(plan.token);
        token.transferFrom(subscriber,plan.merchant,plan.amount);
        emit PaymentSent(subscriber,plan.merchant,plan.amount,planId,block.timestamp);
        subscription.nextPayment = subscription.nextPayment + plan.frequency;
    }

}
