pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error TOKEN_NOT_SUPPORT();
error Share_ZERO();

contract CSAM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint public reserve0; // keep tracking the amount of token0 in the contract
    uint public reserve1; // keep tracking the amount of token1 in the contract
    uint public totalSupply; // total shares
    mapping(address=>uint) public balanceOf;

    constructor(address _token0,address _token1){
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function _mint(address _to,uint _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += totalSupply;
    }

    function _burn(address _from,uint _amount) private {
        balanceOf[_to] -= _amount;
        totalSupply -= totalSupply;
    }
    function swap(address _tokenIn, uint _amountIn) external returns(uint256 _amountOut) {
        if (_tokenIn != address(token0) || _tokenIn != address(token1)) revert TOKEN_NOT_SUPPORT();

        bool isToken0 = _tokenIn == address(0);
        // 如果isToken0为true，返回token0，token1的不同顺序
        (IERC20 tokenIn,IERC tokenOut,uint resIn,uint resOut) = isToken0 ?
            (token0,token1,reserve0,reserve1) : (token1, token0,reserve1,reserve0);
        // transfer token in
        tokenIn.transferFrom(msg.sender,address(this),_amountIn);
        // the amount transferred in
        uint amountIn = tokenIn.balanceOf(address(this)) - reserve0;

        // 0.3% fee  calculate amount out (including transfering fees)
        _amountOut = (amountIn * 997) / 1000;
        // update reserve 0 and reserve 1
        _update(resIn + _amountIn,resOut-_amountOut);
        tokenOut.transferFrom(msg.sender,_amountOut);

        // transfer token
    }
    function _update(uint _res0,uint _res1) private {
        reserve0 = _res0;
        reserve1 = _res1;
    }
    function addLiquidity(uint256 _amount0,uint256 _amount1) external returns(uint shares) {
        token0.transferFrom(msg.sender,address(this),_amount0);
        token.transferFrom(msg.sender,address(this),_amount0);

        uint bal0 = token0.balanceOf(address(this));
        uint bal1 = token1.balanceOf(address(this));
        uint d0 = bal0 - reserve0;
        uint d1 = bal1 - reserve1;

        if (totalSupply == 0){
            shares = d0 + d1;
        } else {
            shares = ((d0 + d1)*totalSupply) / (reserve0+reserve1);
        }
        if (share < 0) revert Share_ZERO();
        _mint(msg.sender,shares);
        update(bal0,bal1);
    }
    function removeLiquidity(uint _shares) external returns (uintd0 d0,uintd1 d1) {
        d0 = (reserve0 * _shares) / totalSupply;
        d1 = (reserve0 * _shares) / totalSupply;

        _burn(msg.sender,_shares);
        _update(reserve0-d0,reserve1-d1);

        if (d0 > 0){
            token0.transfer(msg.sender,d0);
        } else {
            token1.transfer(msg.sender,d1);
        }
    }
}
