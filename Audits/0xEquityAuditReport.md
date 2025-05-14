# **0xEquity Audit Report**

# Introduction :-
The [0xEquity](https://www.0xequity.io/) protocol underwent a time-limited security audit conducted by ([ABDul Rehman](https://twitter.com/TheTradMod)). During the assessment, a total of **1 High**, **3 Medium** & **7 Low** issues were identified and disclosed.

# Qualitative Analysis:
| Metric              | Rating    | Comments                               |
|---------------------|-----------|----------------------------------------|
| Test Coverage       | <span style="color:blue">Fine</span> | ~85%                                  |
| Best Practices      | <span style="color:yellow">Great</span> | Many Followed                      |
| Documentation       | <span style="color:red">Dead</span> | No Docs                                |
| NatSpec Comments    | <span style="color:red">Poor</span> | Should be improved                     |
| Code Quality & Complexity | <span style="color:green">Excellent</span> | Complex but well written  |

Overall, the codebase demonstrates a solid foundation, with the adoption of many best practices. The existing test coverage is satisfactory, although efforts should be made to increase it to a minimum of 95% and ideally strive for comprehensive coverage of 100%. The absence of user and developer documentation poses challenges during the audit process, making it imperative to prioritize the creation of comprehensive documentation. Some contracts have rich NatSpec comments; however, there is a notable absence of comments in many others. To enhance code clarity and understanding, it is recommended to incorporate NatSpec titles for all contracts and functions. It is worth noting that the code itself is exceptionally well-written, showcasing effective handling of the protocol's intricate structure.

# Findings Summary :-
| Label | Description | Severity |
|------|-------------|----------|
| H-01 | Attackers and malicious users can exploit `PriceFeed.setPropertyDetails()` to make a quick profit or prevent loss by frontrunning attacks | High |
| M-01 | Malicious user can front-run `resetMaliciousStakerAmount()` to withdraw rewards before getting blocked | Medium |
| M-02 | Protocol's usability becomes very limited when access to the Chainlink Oracle data feed is blocked or during Chainlink's network outages | Medium |
| M-03 | ERC20 return values unchecked, use `SafeTransfer` consistently | Medium |
| L-01 | Slippage Protection Hardcoded & Very Low | Low |
| L-02 | Upgradeable contracts missing Storage `__gaps` | Low |
| L-03 | Lack of Access control check in `RentShare.harvestRewards()` | Low |
| L-04 | Chainlink Price Feed will fail if tokens have decimals greater than 18 | Low |
| L-05 | Buy/Sell Fee can be set to 99%, consider adding a threshold limit | Low |
| L-06 | `abi.encodePacked()` can result in Hash collision, use `abi.encode()` instead | Low |
| L-07 | Use `safeIncreaseAllownace` consistently instead of `approve` | Low |

# High Risk Findings :-
## H-01: Attackers and Malicious Users can Exploit `PriceFeed.setPropertyDetails()` to make a quick Profit or prevent Loss by Frontrunning attacks. 
The [`PriceFeed.setPropertyDetails()`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/PriceFeed/PriceFeed.sol#L107) function is utilized for setting and updating property prices. However, this functionality can be vulnerable to exploitation by attackers and malicious users.
```solidity
    function setPropertyDetails( //@audit updating property price can fall to frontrun attacks
        string memory _propertySymbol,
        IPriceFeed.Property calldata _propertyDetails
    ) external onlyMaintainer {
        storageParams.propertyDetails[_propertySymbol] = _propertyDetails;
        emit PropertyDetailsUpdated(_propertySymbol, _propertyDetails);
    }
```

#### PoC:
- Initially, the PropertyToken is priced at 100 USD.
- The Maintainer calls the `setPropertyDetails` function to increase the price of the PropertyToken to a new value, let's say 150 USD.
- The Attacker monitors the mempool and observes the Maintainer's transaction to update the PropertyToken price.
- Sensing an opportunity, the Attacker front runs the Maintainer's transaction by submitting their own transaction with a higher gas fee.
- The Attacker calls the `Marketplace.swap()` function to purchase 100 PropertyToken with paying High Gas Fee.
- Due to the higher gas fee, the Attacker's transaction gets executed before the Maintainer's transaction, granting the Attacker ownership of the 100 PropertyTokens at the previous price of 100 USD.
- After the Maintainer's transaction is eventually executed and the price is updated to 150 USD, the Attacker decides to sell all the PropertyTokens he acquired.
- Capitalizing on the price increase, the Attacker successfully sells the 100 PropertyTokens at the new price of 150 USD.
- Attacker makes a quick $5000 profit.

Furthermore, a malicious user can take advantage when the price of the PropertyToken decreases. They can quickly sell the property by frontrunning the updated price transaction and selling the PropertyTokens before incurring any loss.

### Recommended Mitigation:
Consider adding a delay mechanism in the `Marketplace.swap()` function and OCLRouter's buy/sell functions.

#### Note:
This issue will be Fixed, using the already implemented pause/unpause mechanism. Price only will be updated when buying & selling will be paused.
Furthermore, on further discussion following the audit this was acknowledged that MEV Bots can bruttaly exploit this issue using flash-loan attacks.

# Medium Risk Findings :-
## M-01: Malicious user can front-run `resetMaliciousStakerAmount()` to withdraw rewards before getting blocked.
[`resetMaliciousStakerAmount()`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/Rent/RentShare.sol#L271) is used to punish Malicious Stakers but a malicious user can easily bypass it by a frontrunning attack.
```solidity
    ///@audit M can be frontrunned by the malicious user
    function resetMaliciousStakerAmount(
        address _staker,
        uint _poolId
    ) external onlyMaintainer {
        delete storageParams.poolStakers[_poolId][_staker];
    }
```

#### PoC:
- A malicious user identifies the resetMaliciousStakerAmount() function, which is responsible for resetting stake amounts and blocking future rewards.
- The malicious user closely monitors the system.
- When the malicious user detects the execution of the resetMaliciousStakerAmount() function, they quickly front-run the transaction by submitting their own transaction with a higher gas fee.
- By front-running, the malicious user withdraws their staked tokens and claims the rewards before the resetMaliciousStakerAmount() function can block the rewards.
- As a result, the malicious user successfully withdraws their rewards before getting blocked.

### Recommended Mitigation:
Add a delay mechanism in the `harvestRewards()` function 

#### Protocol Devs' Comment:
*Fixed. Added delay mechanism added in harvestRewards().*

## M-02: Protocol's usability becomes very limited, when access to the Chainlink Oracle data feed is blocked or during Chainlink's network outages
The protocol heavily depends on Chainlink's data feeds due to which if chainlink data feeds are blocked or during chainlink network outages, the protocol may encounter significant difficulties. As highlighted in the [OpenZepplin's The-dangers-of-price-oracles](https://blog.openzeppelin.com/secure-smart-contract-guidelines-the-dangers-of-price-oracles/) article, it is possible for Chainlink's multisigs to intentionally block access to price feeds. Additionally, Chainlink has experienced network outages in the past. During these periods, all user calls, such as buy, sell, and redeem, will revert, leading to a Denial-of-Service (DoS) scenario.

### Recommended Mitigation:
1. It is recommended to query Chainlink price feeds using a defensive approach with Solidity’s try/catch structure.
2. Add a fallback oracle
```solidity
function _fetchPriceFromChainlink(address _feedAddress) internal view returns (uint latestPrice) {
    try AggregatorV3Interface(_feedAddress).latestRoundData() returns (
        uint80 roundId,
        int price,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        require(block.timestamp - updatedAt < 1 days, "Price is outdated");
        require(price > 0, "Invalid price");
        require(answeredInRound >= roundId, "Round not complete: STALE PRICE");
        uint8 _decimals = AggregatorV3Interface(_feedAddress).decimals();
        latestPrice = _getScaledValue(price, _decimals);
    } catch Error(string memory) {            
            // handle failure here:
            // revert, call proprietary fallback oracle, fetch from another 3rd-party oracle, etc.
        }
}
```
#### Note: 
Protocol Team is looking forward to this issue. There is already an ongoing discussion to add api3 oracle or any other better Oracle as a backup Oracle.

## M-03: ERC20 return values unchecked, use SafeTransfer Consistently
Throughout the codebase SafeREC20's `safeTranfer()` & `safeTransferFrom()` is used but it's not used on some critical points.

The ERC20.transfer() and ERC20.transferFrom() functions return a boolean value indicating success. This parameter needs to be checked for success. Some tokens do not revert if the transfer failed but return false instead. Tokens that don't actually perform the transfer and return false are still counted as a correct transfer.

[`_transferProperty()`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/libraries/MarketplaceLib.sol#L243) handles a very important task buying & selling the PropertyTokens. In the selling root, it calls three internal functions: [`_borrowTokens()`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/libraries/MarketPlaceBorrowerLib.sol#L90), [`_transferSellFee()`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/libraries/MarketplaceLib.sol#L453) & [`_transferTokensToUser()`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/libraries/MarketplaceLib.sol#L483). All three of these internal functions are transferring ERC20 tokens. Using `.transfer()` to transfer the tokens and ignoring the return values. 
If any of these `.transfer()` failed silently and the TRX executes successfully there can be a loss for the user or for the protocol.

### Recommended Mitigation:
Use SafeREC20's `safeTranfer()` & `safeTransferFrom()` consistently.
There are ~7 instances of this issue in the in-scope contracts. Fix all of them

#### Protocol Devs' Comment:
*Fixed using SafeERC20.*

# Low Risk Findings :-

## L-01: Slippage Hardcoded
There slippage is [hardcoded](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/Rent/RentDistributor.sol#L130) in the `RentDistributor.Reedem()` function, which expose user to sandwich attack.

### Recommended Mitigation:
Let the users determine the maximum slippage they're willing to take. `_minTargetAmount` should be a function param. The protocol front-end should set the recommended value for them.
```solidity
    function redeem(
        uint amount,
        address tokenOut,
        address recipient,
        uint256 minTargetAmount
    ) public nonReentrant {
            .....
            IOCLRouter.DexSwapArgs memory _swapArgs;
            _swapArgs._quoteCurrency = USDC;
            _swapArgs._origin = USDC;
            _swapArgs._target = tokenOut;
            _swapArgs._originAmount = toTransfer;
            _swapArgs._minTargetAmount = minTargetAmount; //@audit slippage protection hardcoded
            _swapArgs._deadline = block.timestamp + (60 * 30);
            _swapArgs._receipient = recipient;
            uint tokensRecieved = IOCLRouter(oclrAddress).swapOnDfx(_swapArgs);
            .....
        }
    }   
```
#### Protocol Devs' Comment:
*Disagree with the Medium Severity The reason is that it had a TODO on it that says "This implementation is to be done in case of out token is not USDC, then what to do?", that means that this current implementation is not valid. Even if we ignore the TODO, if the contract were to be deployed in the current shape, this path would have always reverted as the third-party contract we are calling does not have JTRY/USDC pair, so there exists no sandwich attack vector but DoS. So I will rate it as Low.*

#### Note:
Issue Downgraded. `M --> L`.

## L-02: Upgradeable contracts missing Storage __gaps
Contracts are quite complex, so storage __gaps should be added. That will be quite helpful in future upgrades IA.

Reserve storage __gaps[50] in all the upgradeable contracts.
```solidity
uint256[50] private __gap;
```
https://docs.openzeppelin.com/contracts/3.x/upgradeable#storage_gaps

#### Protocol Devs' Comment:
*Fixed by adding storage gaps.*

## L-03: Lack of Access control check in RentShare.harvestRewards()
 There is a slight access control issue in [`RentShare.harvestRewards()`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/Rent/RentShare.sol#L298).
 
Currently, anyone can call this function and update the state.
However, the state that is getting updated is not critical, so it does not create an attack vector. Nevertheless, there is a possibility of encountering unexpected behavior in the future due to this access control vulnerability. Add a check to make sure only stakers can call this function.
This check will do the work:
```solidity
_require(storageParams.userToPropertyRentClaimTimestamp[_msgSender()][symbol] != 0, "BRUH");
```
Would be better if poolStakers mapping is used in the check.

#### Protocol Devs' Comment:
*Fixed.*

## L-04: Chainlink Price Feed will fail if token's have decimals greater than 18 
No tokens with greater than 18 `_decimals`, will be gonna be able to interacts with the protocol.
```solidity
    function _getScaledValue(
        int256 _unscaledPrice,
        uint8 _decimals
    ) internal pure returns (uint256 price) {
        price = uint256(_unscaledPrice) * (10 ** (18 - _decimals));
    }
```
Add support for [High Decimals](https://github.com/d-xo/weird-erc20#high-decimals) Tokens:
```solidity
    function _getScaledValue(
        int256 _unscaledPrice,
        uint8 _decimals
    ) internal pure returns (uint256 price) {
        if(_decimals <= 18){
        price = uint256(_unscaledPrice) * (10 ** (18 - _decimals));
        } else {
        price = uint256(_unscaledPrice) * (10 ** (_decimals - 18));
        }
    }
```
This will allow tokens with decimals greater than 18, to interact with the protocol by appropriately scaling the price based on the decimals.

#### Protocol Devs' Comment:
*Valid but this will not be fixed. This is intentional as we do not plan to use tokens with decimals >18.*

## L-05: Buy/Sell Fee can be set to 99%
[`updateBuyFeePercentage`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/Marketplace.sol#L253) & [`updateSellFeePercentage`](https://github.com/0xEquity/contracts-v1/blob/1ee013c79fef55bed0d7677ad12ca49729480666/contracts/Marketplace.sol#L270) can be set to the maximum value (99%).
A Maintainer can front-run a user's TRX and set the fee to the max and make some extra bucks.

Consider adding a `constant` max limit like 5% - 10%. This will help the users to trust the protocol.

#### Protocol Devs' Comment:
Fixed by setting a max percentage limit.

## L-06: abi.encodePacked() can result in Hash collision, use abi.encode() instead  
`abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`
abi.encodePacked can result in hash collisions when used with two dynamic arguments (string/bytes). For maximum safety against future mistakes, using abi.encode is recommended.

There is also discussion of removing abi.encodePacked from future versions of Solidity (ethereum/solidity#11593), so using abi.encode now will ensure compatibility in the future.

```diff
-        require(keccak256(abi.encodePacked(_storageParams.poolIdToSymbol[poolId])) == keccak256(abi.encodePacked(tokenSymbol)), "Invalid symbol");
+        require(keccak256(abi.encode(_storageParams.poolIdToSymbol[poolId])) == keccak256(abi.encode(tokenSymbol)), "Invalid symbol");
```
There are many instances of this issue.

#### Protocol Devs' Comment:
*Fixed by using `abi.encode()`*

## L-07: Use `safeIncreaseAllownace()` consistently instead of `approve()`
ERC20's `safeIncreaseAllownace()` is used throughout the codebase but `approve()` is used on some places as well. Even tho, I don't think there is much issue with `approve()` but still Consider using `safeIncreaseAllownace()` everywhere as it is regarded as a best practice in the space.

#### Protocol Devs' Comment:
*Fixed by using `safeIncreaseAllownace()`*

# Scope :-
In total **47 Contracts** encompassing approximately **4637 SLOC** were IN-SCOPE. 
Vulnerablities related to price stalness due to incorrect oracle were out-of-scope. And the audit was only focused on High, Med & Low Findings.
The review was focused on the commit hash - [1ee013c79fef55bed0d7677ad12ca49729480666](https://github.com/0xEquity/contracts-v1/commit/1ee013c79fef55bed0d7677ad12ca49729480666) of 0xEquity's contracts-v1 repo (private).

# Disclaimer :-
*This audit report does not serve as an all-encompassing guarantee of identifying and resolving all vulnerabilities. While extensive efforts have been made to meticulously review the smart contracts for potential vulnerabilities, it is not feasible to ensure absolute absence of vulnerabilities. The audit process is constrained by limitations in time and resources, making it impossible to guarantee the discovery of all vulnerabilities or guarantee complete security of the smart contracts following the audit. The auditor cannot be held responsible for any damages or losses arising from the use of the contracts in question.
Subjecting the protocol to further audits before its mainnet launch is strongly recommended. Additionally, implementing a bug bounty program and actively monitoring all on-chain events after the mainnet launch will significantly contribute to enhancing the overall security measures.
Thank you for your understanding and cooperation.*