// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./IMSLA.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
*/
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract PaymentSplit is ChainlinkClient, IUniswapV2Router02, Ownable {

    using Chainlink for Chainlink.Request;
    IMSLA public _IMSLA;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    uint256 private tokenPrice;
    address private WETH;
    uint256[] private allowedAmount;
    address[] private tokenAddress;
    mapping(address => uint256[]) public balanceForAddress;
    mapping(address => uint256) public lastReleaseTime;
    mapping(bytes32 => address) private requestAddress;

    event RequestMultipleFulfilled(bytes32 requestId, uint256 ethBalance, uint256 wethBalance, uint256 usdcBalance, uint256 usdtBalance, uint256 daiBalance);

    constructor(uint256 _tokenPrice, address link, address oracle, IMSLA _NFTAddress, uint256[] _allowedAmount) {
        tokenAddress[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH Address on Ethereum Mainnet
        tokenAddress[2] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC Address on Ethereum Mainnet
        tokenAddress[3] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT Address on Ethereum Mainnet
        tokenAddress[4] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI Address on Ethereum Mainnet
        linkAddress = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK Address on Ethereum Mainnet
        IUniswapV2Router02 uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router Address
        WETH = uniswapRouter.WETH();
        _IMSLA = _NFTAddress;
        setChainlinkToken(link);
        setChainlinkOracle(oracle);
        fee = 0.1 * 10 ** 18;
        tokenPrice = _tokenPrice;
        allowedAmount = _allowedAmount;
    }

    modifier onlyPayee(address _requestAddress) {
        require(_IMSLA.balanceOf(_requestAddress) > 0, "Not Allowed Payee.");
        _;
    }

    function updateUserBalance(bytes32 specId, address requestAddress) public payable onlyPayee(requestAddress) {
        require(msg.value * tokenPrice > fee, "Not enough Transfer Fee");
        uniswapRouter.swapETHForExactTokens(fee, [WETH, linkAddress], address(this), block.timestamp + 600);
        Chainlink.Request memory req = buildChainlinkRequest(specId, requestAddress, this.fulfillMultipleParameters.selector);
        bytes32 reqId = sendChainlinkRequest(req, fee);
        requestAddress[reqId] = requestAddress;
    }

    function fulfillMultipleParameters(bytes32 requestId, uint256 ethBalance, uint256 wethBalance, uint256 usdcBalance, uint256 usdtBalance, uint256 daiBalance) public recordChainlinkFulfillment(requestId) {
        emit RequestMultipleFulfilled(requestId, ethBalance, wethBalance, usdcBalance, usdtBalance, daiBalance);
        balanceForAddress[requestAddress[requestId]] = [ethBalance, wethBalance, usdcBalance, usdtBalance, daiBalance];
    }

    function release() public virtual onlyPayee(msg.sender) {
        require(lastReleaseTime[msg.sender] > 86400, "Release is allowed only once per day.");
        if(balanceForAddress[msg.sender][0] > 0){
            require(address(this).balance > balanceForAddress[msg.sender][0], "Insufficient Balance on Contract.");
            require(allowedAmount[0] > balanceForAddress[msg.sender][0], "Not Allowed Amount");
            Address.sendValue(msg.sender, balanceForAddress[msg.sender][0]);
        }
        for(uint8 i = 1; i < 5; i++) {
            if(balanceForAddress[msg.sender][i] > 0) {
                IERC20 token = tokenAddress[i];
                require(token.balanceOf(address(this)) > balanceForAddress[msg.sender][i], "Insufficient Balance on Contract.");
                require(allowedAmout[i] > balanceForAddress[msg.sender][i], "Not Allowed Amount");
                SafeERC20.safeTransfer(token, msg.sender, balanceForAddress[msg.sender][i]);
            }
        }
        lastReleaseTime[msg.sender] = block.timestamp;
    }

    function secureTransfer(address _toAddress) public onlyOwner {
        Address.sendValue(_toAddress, address(this).balance);
        for (uint8 i = 1; i < 5; i ++) {
            IERC20 token = tokenAddress[i];
            SafeERC20.safeTransfer(token, _toAddress, token.balanceOf(address(this)));
        }
    }

    function updateConstruct(address oracle) public onlyOwner {
        setChainlinkOracle(oracle);
    }

    function setMaxAllowAmount(uint256[] newAmount) public onlyOwner {
        allowedAmount = newAmount;
    }

    function setTokenPrice(uint256 newPrice) public onlyOwner {
        tokenPrice = newPrice;
    }

    function getTokenPrice() public view returns (uint256) {
        return tokenPrice;
    }
}