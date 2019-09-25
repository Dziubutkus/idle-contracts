pragma solidity 0.5.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

import "../interfaces/iERC20Fulcrum.sol";
import "../interfaces/ILendingProtocol.sol";

contract IdleFulcrum is ILendingProtocol, Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  // protocol token (iToken) address
  address public token;
  // underlying token (token eg DAI) address
  address public underlying;

  constructor(address _token, address _underlying) public {
    token = _token;
    underlying = _underlying;
  }

  // x = (sqrt(a) sqrt(b) sqrt(o) sqrt(s) - sqrt(k) sqrt(q) s)/(sqrt(k) sqrt(q))

  /* const maxDAIFulcrumFoo = q1 =>
    a1.sqrt().times(b1.sqrt()).times(o1.sqrt()).times(s1.sqrt()).minus(k1.sqrt().times(q1.sqrt()).times(s1)).div(k1.sqrt().times(q1.sqrt())); */

  function maxAmountBelowRate()
    external view
    returns (uint256) {}

  function nextSupplyRate(uint256 _amount)
    external view
    returns (uint256 nextRate) {
      iERC20Fulcrum iToken = iERC20Fulcrum(token);
      nextRate = iToken.nextSupplyInterestRate(_amount);
      // remove 10% mandatory self insurance
      nextRate = nextRate.mul(iToken.spreadMultiplier()).div(10 ** 20);
  }

  function getPriceInToken()
    external view
    returns (uint256) {
      return iERC20Fulcrum(token).tokenPrice();
  }

  function getAPR()
    external view
    returns (uint256 apr) {
      iERC20Fulcrum iToken = iERC20Fulcrum(token);
      apr = iToken.supplyInterestRate(); // APR in wei 18 decimals
      // remove Mandatory self-insurance of Fulcrum from iApr
      // apr * spreadMultiplier / (100 * 1e18)
      apr = apr.mul(iToken.spreadMultiplier()).div(10 ** 20);
  }

  function mint()
    external
    /* onlyIdleMain */
    returns (uint256 iTokens) {
      // Funds needs to be sended here before calling this
      uint256 balance = IERC20(underlying).balanceOf(address(this));
      if (balance == 0) {
        return iTokens;
      }
      // approve the transfer to iToken contract
      IERC20(underlying).safeIncreaseAllowance(token, balance);
      // mint the iTokens and transfer to msg.sender
      iTokens = iERC20Fulcrum(token).mint(msg.sender, balance);
  }

  function redeem(address _account)
    external
    /* onlyIdleMain */
    returns (uint256 tokens) {
    // Funds needs to be sended here before calling this
    tokens = iERC20Fulcrum(token).burn(_account, IERC20(token).balanceOf(address(this)));
  }
}
