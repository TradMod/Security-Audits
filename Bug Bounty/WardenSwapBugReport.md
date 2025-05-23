## Dangerous Payable Function in DEX Smart Contract May Cause Permanent Locking of ETH

### **Bug Description**

The `WardenRouterV2.swap()` function may cause permanent loss of Ether if used incorrectly.

The function allows users to swap using either native Ethers (BNB) or ERC20 tokens. However, due to missing input validation, if a user supplies valid ERC20 token parameters **and** sends ETH (`msg.value`), the ETH is accepted but not used or refunded. This results in the ETH being permanently locked in the contract.

Moreover, the contract does not support receiving native ETH directly—making this behavior unintended and dangerous. This bug can also serve as a surface enabler for further vulnerabilities by allowing user funds to be absorbed into the contract.

---

## **Impact**

* Permanent loss of user ETH
* ETH locked in the contract with no recovery path

---

## **Risk Breakdown**

* **Difficulty to Exploit:** Low (accidental user behavior)
* **Weakness:** Missing input validation
* **CVSS v2 Score:** N/A
* **Severity:** Low (due to low likelihood, despite financial impact)

---

## **Recommendation**

Add input validation to explicitly reject transactions where `msg.value > 0` if the source token is not native ETH:

```solidity
if (ETHER_ERC20 == _src) {
    require(msg.value == _srcAmount, "WardenRouter::swap: Ether source amount mismatched");
    weth.deposit{value: newSrcAmount}();
    IERC20(address(weth)).safeTransfer(_deposits, newSrcAmount);
} else {
    require(msg.value == 0, "WardenRouter::swap: Ether sent with ERC20 Tokens");
    _src.safeTransferFrom(msg.sender, _deposits, newSrcAmount);
}
```


## **Proof of Concept**

```solidity
function testLossOfFundsSwap(uint a, uint b, uint c) public {
    deal(address(token), abdee, 10 ether);
    startHoax(abdee, 10 ether);
    token.approve(address(wardenRouter), 10 ether);

    // 10 ether & 10 tokens sent
    wardenRouter.swap{value: 10 ether }(
        wardenSwap,
        "",
        address(0xb33EaAd8d922B1083446DC23f610c2567fB5180f), 
        token,
        10 ether,
        token,
        a,
        address(0),
        b,
        c
    );

    // Tokens transferred
    assertEq(token.balanceOf(abdee), 0);

    // ETH lost
    assertEq(abdee.balance, 0);
}
```

![Image](https://github.com/user-attachments/assets/e0f7aa38-e880-4d7b-ad0b-82670f5200bd)