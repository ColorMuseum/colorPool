// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@trustus/src/Trustus.sol";
import {console} from "../test/utils/console.sol";

contract PaymentSplit is ChainlinkClient, Ownable ,Trustus{

    // using Chainlink for Chainlink.Request;
    address public NFTAddress;

    bytes32 public merkleRoot;// = 0x..........
    bytes32 private jobId;
    uint256 private fee;
    uint256 private tokenPrice;
    address private WETH;
    address private linkAddress;
    IUniswapV2Router02 private uniswapRouter;
    uint256[] private allowedAmount;
    address[5] private tokenAddress;

    mapping(address => uint256[]) public balanceForAddress;
    mapping(address => uint256) public lastReleaseTime;
    mapping(bytes32 => address) private requestAddress;
    mapping (address => bool) userAddr;

    event RequestMultipleFulfilled(bytes32 requestId, uint256 ethBalance, uint256 wethBalance, uint256 usdcBalance, uint256 usdtBalance, uint256 daiBalance);

    constructor(uint256 _tokenPrice,  address _NFTAddress, uint256[] memory _allowedAmount) {// address link, address _oracle,
        tokenAddress[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH Address on Ethereum Mainnet
        tokenAddress[2] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC Address on Ethereum Mainnet
        tokenAddress[3] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT Address on Ethereum Mainnet
        tokenAddress[4] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI Address on Ethereum Mainnet
        linkAddress = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK Address on Ethereum Mainnet
        address _uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 Router Address
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        NFTAddress = address(this);
        tokenPrice = _tokenPrice;
        allowedAmount = _allowedAmount;
    }

    modifier onlyPayee(address _requestAddress,bytes32[] memory proof) {
        require(IERC20(NFTAddress).balanceOf(_requestAddress) > 0 || proof.verify(merkleRoot, keccak256(abi.encodePacked(_requestAddress))), "Not Allowed Payee.");
        // require(userAddr[_requestAddress], "Not Allowed Payee.");
        _;
    }
    
    function withdraw(bytes32 request, TrustusPacket calldata packet,bytes32[] memory proof) public onlyPayee(msg.sender,proof){
        _setIsTrusted(msg.sender,true);
        require(_verifyPacket(request, packet));
        _release(packet.payload);
    }

    function _release(uint256[5] memory balanceForAddress) internal{
      require(lastReleaseTime[msg.sender] > 86400, "Release is allowed only once per day.");
        if(balanceForAddress[0] > 0){
            require(address(this).balance > balanceForAddress[0], "Insufficient Balance on Contract.");
            require(allowedAmount[0] > balanceForAddress[0], "Not Allowed Amount");
            Address.sendValue(payable(msg.sender), balanceForAddress[0]);
        }
        for(uint8 i = 1; i < 5; i++) {
            if(balanceForAddress[i] > 0) {
                IERC20 token = IERC20(tokenAddress[i]);
                require(token.balanceOf(address(this)) > balanceForAddress[i], "Insufficient Balance on Contract.");
                require(allowedAmount[i] > balanceForAddress[i], "Not Allowed Amount");
                SafeERC20.safeTransfer(token, msg.sender, balanceForAddress[i]);
            }
        }
        lastReleaseTime[msg.sender] = block.timestamp;
    }

    function secureTransfer(address _toAddress) public onlyOwner {
        Address.sendValue(payable(_toAddress), address(this).balance);
        for (uint8 i = 1; i < 5; i ++) {
            IERC20 token = IERC20(tokenAddress[i]);
            SafeERC20.safeTransfer(token, _toAddress, token.balanceOf(address(this)));
        }
    }

    function updateConstruct(address _oracle) public onlyOwner {
        setChainlinkOracle(_oracle);
    }

    function setMaxAllowAmount(uint256[] memory newAmount) public onlyOwner {
        allowedAmount = newAmount;
    }

    function setTokenPrice(uint256 newPrice) public onlyOwner {
        tokenPrice = newPrice;
    }
    function setWhiteListRoot(bytes32 newRoot) public onlyOwner {
        merkleRoot = newRoot;
    }
    // function whitelistAddress (address[] memory users) public onlyOwner {
    //     for (uint i = 0; i < users.length; i++) {
    //         userAddr[users[i]] = true;
    //     }
    // }

    function getTokenPrice() public view returns (uint256) {
        return tokenPrice;
    }
}