pragma solidity 0.5.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

import "../interfaces/CERC20.sol";
import "../interfaces/ILendingProtocol.sol";
import "../interfaces/WhitePaperInterestRateModel.sol";

contract IdleCompound is ILendingProtocol, Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  // protocol token (cToken) address
  address public token;
  // underlying token (token eg DAI) address
  address public underlying;

  constructor(address _token, address _underlying) public {
    token = _token;
    underlying = _underlying;
  }
  /* const a = BNify(baseRate);
  const b = BNify(totalBorrows);
  const c = BNify(multiplier);
  const d = BNify(totalReserves);
  const e = BNify(1e18).minus(BNify(reserveFactorMantissa));
  let s = BNify(getCash);
  // const q = BNify(targetSupplyRate);
  const x = newDAIAmount;
  const k = BNify(2102400); // blocksInAYear
  const j = BNify(1e18); // oneEth
  const f = BNify(100);

  x = (sqrt(a^2 b^2 e^2 f^2 + 2 a b d e f j q + 4 b^2 c e f j q + d^2 j^2 q^2) + a b e f - 2 b j q + d j q - 2 j q s)/(2 j q)

  const maxDAICompoundFoo = q =>
    a.pow(2).times(b.pow(2)).times(e.pow(2)).times(f.pow(2)).plus(
      BNify('2').times(a).times(b).times(d).times(e).times(f).times(j).times(q).plus(
        BNify('4').times(b.pow(2)).times(c).times(e).times(j).times(f).times(q).plus(
          d.pow(2).times(j.pow(2)).times(q.pow(2))
        )
      )
    ).sqrt().plus(
      a.times(b).times(e).times(f)
    ).minus(BNify('2').times(b).times(j).times(q)).plus(
      d.times(j).times(q)
    ).minus(
      BNify('2').times(j).times(q).times(s)
    ).div(BNify('2').times(j).times(q)); */
  function maxAmountBelowRate()
    external view
    returns (uint256) {}

  function nextSupplyRate(uint256 _amount)
    external view
    returns (uint256 nextRate) {
      CERC20 cToken = CERC20(token);
      WhitePaperInterestRateModel white = WhitePaperInterestRateModel(cToken.interestRateModel());

      uint256 j = 10 ** 18;
      uint256 a = white.baseRate(); // from WhitePaper
      uint256 b = cToken.totalBorrows();
      uint256 c = white.multiplier(); // from WhitePaper
      uint256 d = cToken.totalReserves();
      uint256 e = j.sub(cToken.reserveFactorMantissa());
      uint256 s = cToken.getCash();
      uint256 x = _amount;
      uint256 k = cToken.blocksInAYear();
      uint256 f = 100;

      // q = ((((a + (b*c)/(b + s + x)) / k) * e * b / (s + x + b - d)) / j) * k * f -> to get yearly rate
      nextRate = a.add(b.mul(c).div(b.add(s).add(x))).div(k).mul(e).mul(b).div(
        s.add(x).add(b).sub(d)
      ).div(j).mul(k).mul(f); // to get the yearly rate
  }

  function getPriceInToken()
    external view
    returns (uint256) {
      return CERC20(token).exchangeRateStored();
  }

  function getAPR()
    external view
    returns (uint256 apr) {
    CERC20 cToken = CERC20(token);
    uint256 cRate = cToken.supplyRatePerBlock(); // interest % per block
    apr = cRate.mul(cToken.blocksInAYear()).mul(100);
  }

  function mint()
    external
    /* onlyIdleMain */
    returns (uint256 cTokens) {
      // Funds needs to be send here before calling this
      uint256 balance = IERC20(underlying).balanceOf(address(this));
      if (balance == 0) {
        return cTokens;
      }
      // approve the transfer to cToken contract
      IERC20(underlying).safeIncreaseAllowance(token, balance);

      // get a handle for the corresponding cToken contract
      CERC20 _cToken = CERC20(token);
      // mint the cTokens and assert there is no error
      require(_cToken.mint(balance) == 0, "Error minting");
      // cTokens are now in this contract
      // transfer them to the caller
      cTokens = IERC20(token).balanceOf(address(this));
      IERC20(token).safeTransfer(msg.sender, cTokens);
      /* // generic solidity formula is exchangeRateMantissa = (underlying / cTokens) * 1e18
      uint256 exchangeRateMantissa = _cToken.exchangeRateStored(); // (exchange_rate * 1e18)
      // so cTokens = (underlying * 1e18) / exchangeRateMantissa
      cTokens = _amount.mul(10**18).div(exchangeRateMantissa); */
  }

  function redeem(address _account)
    external
    /* onlyIdleMain */
    returns (uint256 tokens) {
      // Funds needs to be sended here before calling this
      CERC20 _cToken = CERC20(token);
      IERC20 _underlying = IERC20(underlying);
      // redeem all underlying sent in this contract
      require(_cToken.redeem(IERC20(token).balanceOf(address(this))) == 0, "Something went wrong when redeeming in cTokens");

      /* // generic solidity formula is exchangeRateMantissa = (underlying / cTokens) * 1e18
      uint256 exchangeRateMantissa = _cToken.exchangeRateStored(); // exchange_rate * 1e18
      // so underlying = (exchangeRateMantissa * cTokens) / 1e18
      tokens = _amount.mul(exchangeRateMantissa).div(10**18); */

      tokens = _underlying.balanceOf(address(this));
      _underlying.safeTransfer(_account, tokens);
  }
}
