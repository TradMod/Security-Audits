// SPDX-License-Identifier: MIT
pragma solidity 0.8.8; 

contract DangerousPayableFunctionPOC {
     function testLossOfFundsSwap(uint a, uint b, uint c) public {
        deal(address(token), abdee, 10 ether);
        startHoax(abdee, 10 ether);
        token.approve(address(protocolRouter), 10 ether);

        // 10 ether & 10 tokens
        protocolRouter.swap{value: 10 ether }(
            protocol,
            "",
            address(0xb33EaAd8d922B1083446DC23f610c2567fB5180f), 
            token,
            10 ether,
            token,
            a,
            address(0),
            b,
            c);

        //10 tokens gets transfered    
        assertEq(token.balanceOf(abdee), 0);

        //user loses 10 ether
        assertEq(abdee.balance, 0);
}
} 