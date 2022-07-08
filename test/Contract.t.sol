// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../src/Contract.sol";
import {BaseTest, console} from "./base/BaseTest.sol";
import {Trustus} from "@trustus/src/Trustus.sol";
import {TrustusImpl} from "./utils/TrustusImpl.sol";

contract ContractTest is BaseTest{
    PaymentSplit paycontract;
    uint256 _tokenPrice;
    address _NFTAddress; 
    uint256[] _allowedAmount;
    mapping (address => uint256) userAddr;

    Trustus.TrustusPacket packet;
    TrustusImpl trustus;
    
    address trustedAddress = 0x703484b2c3f1e5f4034C27C979Fe600eAf247086;
    bytes32 request = "GetPrice(address)";
    uint256 deadline = block.timestamp + 100000;
    uint256[5] payload = [0,0,0,0,0];

    bytes32 r =
        0x232026443bc5527254d0e38f3ef3c34d08c6bbea4b19e347ef9b8ef8ff373ead;
    bytes32 s =
        0x15a5fedbef81fad075fe0bf3933a642d457ac7aa57d60e2a00e1f264b4ef983b;
    uint8 v = 28;

    function setUp() public {
        _tokenPrice = 1000.0;
        _NFTAddress = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        _allowedAmount =[uint256(0),100,100,100,100,100];
        paycontract = new PaymentSplit(_tokenPrice,_NFTAddress,_allowedAmount);
    }

    function bytes32ToBytes(bytes32 b_) private pure returns (bytes memory){
        return abi.encodePacked(b_);
    }

    function testGetSignature() public view{
        bytes32 result = paycontract.DOMAIN_SEPARATOR();
        console.logBytes(bytes32ToBytes(result));
    }

    function testVerify() public {
        trustus = new TrustusImpl(trustedAddress);
        packet = Trustus.TrustusPacket({
            v: v,
            r: r,
            s: s,
            request: request,
            deadline: deadline,
            payload: payload
        });
        address[] memory users = new address[](1);
        users[0]=address(0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);
    //  paycontract.whitelistAddress(users);
        paycontract.setTrustedPublicKey(0x703484b2c3f1e5f4034C27C979Fe600eAf247086);
        paycontract.withdraw(request,packet);
    }

    function testwithdrawFunction() public virtual{

    //    paycontract.release(result,);
//        console.log("address:",rlt);
    }
}
