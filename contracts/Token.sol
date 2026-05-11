// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  mapping (address => mapping (address => uint256)) private allowances;
  mapping (address => uint256) private withdrawableDividends;
  mapping (address => uint256) private holderIndexes;
  address[] private tokenHolders;

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Token: no ETH supplied");

    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _syncHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "Token: no tokens to burn");

    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _syncHolder(msg.sender);

    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return tokenHolders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > tokenHolders.length) {
      return address(0);
    }

    return tokenHolders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Token: no dividend supplied");
    require(totalSupply > 0, "Token: no token holders");

    for (uint256 i = 0; i < tokenHolders.length; i += 1) {
      address holder = tokenHolders[i];
      uint256 share = msg.value.mul(balanceOf[holder]).div(totalSupply);
      withdrawableDividends[holder] = withdrawableDividends[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = withdrawableDividends[msg.sender];
    require(amount > 0, "Token: no dividend to withdraw");

    withdrawableDividends[msg.sender] = 0;
    dest.transfer(amount);
  }

  function _transfer(address from, address to, uint256 value) private {
    require(to != address(0), "Token: transfer to zero address");

    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    _syncHolder(from);
    _syncHolder(to);
  }

  function _syncHolder(address holder) private {
    if (holder == address(0)) {
      return;
    }

    uint256 index = holderIndexes[holder];

    if (balanceOf[holder] > 0 && index == 0) {
      tokenHolders.push(holder);
      holderIndexes[holder] = tokenHolders.length;
    } else if (balanceOf[holder] == 0 && index > 0) {
      uint256 lastIndex = tokenHolders.length;
      address lastHolder = tokenHolders[lastIndex - 1];

      if (index != lastIndex) {
        tokenHolders[index - 1] = lastHolder;
        holderIndexes[lastHolder] = index;
      }

      tokenHolders.pop();
      holderIndexes[holder] = 0;
    }
  }
}
