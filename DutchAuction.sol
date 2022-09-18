// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

error Auction_Closed();
error Not_Enough();
interface IERC721 {
    function transformFrom(
        address _from,
        address _to,
        uint nftId
    );
}
contract DutchAuction {

    uint private constant DURATION = 7 days;

    IERC721 public immutable nft;
    uint256 public immutable nftId;
    address payable public immutable seller;
    uint256 public immutable startingPrice;
    uint256 public immutable discount;
    uint256 public immutable expireAtl;
    uint256 public immutable startAt;

    constructor(
        uint256 _startingPrice,
        uint256 _discountRate,
        address _nft,
        uiny256 _nftId
    ) {
        seller = payable(msg.sender);
        startingPrice =_startingPrice;
        discountRate = _discountRate;
        startAt = block.timestamp;
        expireAtl = block.timestamp + duration;
        nft = IERC721(_nft);
        nftId = _nftId;
    }
    function getPrice() public view returns (uint){
        uint timeElapsed = block.timestamp - startAt;
        uint discount = discountRate * timeElapsed;
        return startingPrice - discount;
    }

    function buy() external payable {
        if (block.timestamp > expireAtl) revert Auction_Closed();
        uint price =getPrice;
        if (msg.value <= price) revert Not_Enough();
        nft.transformFrom(seller,msg.sender,nftId);
        uint refund = msg.value - price;
        if (refund >0){
            payable(msg.sender).transfer(refund);
        }
        selfdestruct(seller);
    }
}
