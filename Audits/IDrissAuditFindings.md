| Label | Description |
|------|--------------|
| H-01 | Users can transfer multiple NFTs by just paying for 1 NFT transfer fee |
| M-01 | Donating NFTs to Optimism Public Good Address costs fee |
| M-02 | Wrong functionion selector, selected for ERC721 |
| M-03 | Use safetransfer instead of transfer for transferring ERC20 Tokens |
| M-04 | Chainlink Oracle priceFeed Data may return Stale Prices due to improper validation |
| M-05 | Unncessearily Complicated & Buggy batch functionality implementation |
| L-01 | Dangerous `payable` function: Users may accidentaly send Native coins and lose it |
| L-02 | Revert conditions not handled well |
| I-01 | Variable defined but not used/set |
| I-02 | Dev commnets and param commnets missing |
| I-03 | Use reentrancy locks/gaurds |
| I-04 | Take fees in Native coins for the ERC20 as well or consider using a ERC20 Tokens Whitelist |
| I-05 | Use Named imports consistently |
| I-06 | Contract & File name mismatch |
| I-07 | Wrong Comment |
| G-01 | Use `if/else` to check the public good address and setting the payment value |
| G-02 | Use custom errors instead of require/revert strings msgs |

# High Risk Findings
## H-01: Users can transfer multiple NFTs by just paying for 1 NFT transfer fee
`TippingOp.batch()` allows users to transfer multiple assets to multiple users. The protocol takes transfer fee for every asset transfer. The fee mechanism is well implemented in the single asset transfer functions like `sendERC721To()` but breaks in the `batch()` function in the case of NFTs (ERC721 & ERC1155).
The `Batchable.batchCall()` tries to handle the double-spending fee issue by using `msgValueSentAcc`, which apparently should make sure that the `msg.value` should cover the fees for all the assets. `msgValueSentAcc` is dependent on the `currentCallPriceAmount`, which is used to determine the fee for all the assets seperately. And the `calculateMsgValueForACall()` is used to calculate the `currentCallPriceAmount`.
```solidity
          uint256 currentCallPriceAmount = calculateMsgValueForACall(sig, data);
          _MSG_VALUE = currentCallPriceAmount;
          msgValueSentAcc += currentCallPriceAmount;
          require (msgValueSentAcc <= msg.value, "Can't send more than msg.value");
```
The problem is that `calculateMsgValueForACall` will always return zero becasue of the hardcoded zero input values to `getPaymentFee()`:
```solidity
    function calculateMsgValueForACall(bytes4 _selector, bytes memory _calldata) override view internal returns (uint256) {
        uint256 currentCallPriceAmount;

        if (_selector == this.sendTo.selector) {
            assembly {
                currentCallPriceAmount := mload(add(_calldata, 68))
            }
        } else if (_selector == this.sendTokenTo.selector) {
            currentCallPriceAmount = getPaymentFee(0, AssetType.Token);
        ///@audit-issue H 0 value for ERC721 & ERC1155, it will open doors for fee double spending issue
        } else if (_selector == this.sendTokenTo.selector) {
            currentCallPriceAmount = getPaymentFee(0, AssetType.NFT);
        } else {
            currentCallPriceAmount = getPaymentFee(0, AssetType.ERC1155);
        }

        return currentCallPriceAmount;
    }
```
In the case of ERC20 (AssetType.Token) its correct because `sendTokenTo()` cuts fee from the sent tokens but ERC721 & ERC1155 takes fee in the Native Coins (`msg.value`) so that means `msgValueSentAcc` check will not restrict users to pay fee for all the assets transfers beacause its always will be zero:
```solidity
         ///@audit H this actually means: 0 <= msg.value - that mean fee for ERC721 & ERC1155 can be double spent
         require (msgValueSentAcc <= msg.value, "Can't send more than msg.value");
```

### Recommended Mitigation:
Do not hardcode the values to zero for the ERC721 & ERC777 in the calculateMsgValueForACall() function.

Note: This might break the batch functionality, nvm batch is already broken as explained in `H-02`, so with the new implemntation be careful about it.

# Medium Risk Findings
## M-01: Donating NFTs to Optimism Public Good Address costs fee
Assets transfer to optimism public good address shouldn't take [fees](https://help.optimism.io/hc/en-us/articles/5608921918875-What-are-public-goods-). The protocol makes sure that in the case of native Coins and ERC20 tokens but not in the ERC721 & ERC1155 case. As the `sendERC721()` & `sendERC1155()` doesn't check if the recipinet is Optimism Public Good Address or not.

### Recommended Mitigation:
Add Optimism Public Good Address check in both `sendERC721()` & `sendERC1155()` functions and if the adress is public good address then make sure `msg.value` is zero.
```solidity
        if (publicGoods[_recipient]) {
            require(msg.value == 0);
            _attestDonor(_recipient);
        } else {
            uint256 msgValue = _MSG_VALUE > 0 ? _MSG_VALUE : msg.value;
            (uint256 fee,) = _splitPayment(msgValue, AssetType.NFT);
        }
```
Note: This might break the batch functionality, nvm batch is already broken as explained in `H-02`, so with the new implemntation be careful about it.

## M-02: Wrong functionion selector, selected for ERC721. 
`TippingOp.calculateMsgValueForACall()` is using the Wrong functionion selector for the ERC721, which will cause users to pay the wrong & unexpected fee: 
```solidity
    function calculateMsgValueForACall(bytes4 _selector, bytes memory _calldata) override view internal returns (uint256) {
        .....
        } else if (_selector == this.sendTokenTo.selector) {
            currentCallPriceAmount = getPaymentFee(0, AssetType.Token);
        ///@audit-issue M selecting wrong selector
        } else if (_selector == this.sendTokenTo.selector) {
            currentCallPriceAmount = getPaymentFee(0, AssetType.NFT);
        } else {
            currentCallPriceAmount = getPaymentFee(0, AssetType.ERC1155);
        }
        return currentCallPriceAmount;
    }
```
### Recommended Mitigation:
It should be `_selector == this.sendERC721To.selector`
```diff
    function calculateMsgValueForACall(bytes4 _selector, bytes memory _calldata) override view internal returns (uint256) {
        .....
        } else if (_selector == this.sendTokenTo.selector) {
            currentCallPriceAmount = getPaymentFee(0, AssetType.Token);
        ///@audit-issue M selecting wrong selector
-       } else if (_selector == this.sendTokenTo.selector) {
+       } else if (_selector == this.sendERC721To.selector) {
        currentCallPriceAmount = getPaymentFee(0, AssetType.NFT);
        } else {
            currentCallPriceAmount = getPaymentFee(0, AssetType.ERC1155);
        }
        return currentCallPriceAmount;
    }
```

## M-03: Use safetransfer instead of transfer for transferring ERC20 Tokens
The protocol intends to support all ERC20 tokens. Some tokens (like USDT) do not implement the EIP20 standard correctly and their transfer/transferFrom function return void instead of a success boolean. Calling these functions with the correct EIP20 function signatures will revert.
```solidity
    function _sendTokenAsset (
        uint256 _amount,
        address _to,
        address _contractAddress
    ) internal {
        IERC20 token = IERC20(_contractAddress);
        ///@audit M use safeTranfer
        bool sent = token.transfer(_to, _amount);
        require(sent, "Failed to transfer token");
    }
```
There are 3 instances of this issue.

### Recommended Mitigation:
Use OpenZeppelin's SafeERC20 versions with the safeTransfer and safeTransferFrom functions that handle the return value check as well as non-standard-compliant tokens.


## M-04: Chainlink Oracle priceFeed Data may return Stale Prices due to improper validation
The Chainlink price oracle can return stale prices, which could have adverse consequences, users paying low fees then expected. To mitigate this risk, it is crucial to implement robust checks that revert transactions in the event of such prices being returned. The `_dollarToWei()` function is utilized in `_splitPayment()` which is present on many instances of TippingOP.sol, and it lacks essential checks that need to be incorporated. Addressing these deficiencies is imperative to ensure the accuracy and reliability of the price data provided by the oracle.
```solidity
    function _dollarToWei() internal view returns (uint256) {
        ///@audit-issue M stale Prices checks missing 
        (,int256 maticPrice,,,) = MATIC_USD_PRICE_FEED.latestRoundData();
        require (maticPrice > 0, "Unable to retrieve MATIC price.");
        .....
    }
```
### Recommended Mitigation:
These 3 essential checks should be implemented:
1. startedAt value is greater than zero
2. The returned price is not older than 24 hours using startedAt
3. Round Completeness

For more robustness, try/catch to handle chainlink errors, can be added

```solidity
function _dollarToWei() external view override returns (uint256) {
    try MATIC_USD_PRICE_FEED.latestRoundData() returns (uint80 roundID, int256 price, uint256 startedAt, uint256 timeStamp, uint80 answeredInRound) {
        require(price > 0, "Invalid price");
        require(startedAt > 0, "Invalid startedAt");
        require(block.timestamp - startedAt < 1 days, "Price is outdated");
        require(answeredInRound >= roundID, "Round not complete");

        return uint256(price) * 1e10;
    } catch Error(string memory) {            
            // handle failure here:
            // revert, call proprietary fallback oracle, fetch from another 3rd-party oracle, etc.
        }
}
```
Reference: OpenZeppelin - [The Dangers of Price Oracles](https://blog.openzeppelin.com/secure-smart-contract-guidelines-the-dangers-of-price-oracles)

## M-05: Unncessearily Complicated & Buggy batch functionality implementation
The batch functionality is used to distribute multipole assests, but there are so many problems with current implementation. This functionality can be easily done with simple & secure implementation. Let's first discuss the main problems with the current batch functionality;
1. Batch takes an arbitrary array of values as an Input:
```solidity
    function batch(bytes[] calldata _calls) external payable {
        batchCall(_calls);
    }
```
The `_calls` data is used in the `delegatecall` to the contract (address(this)). This can be really dangerous. Input for function like this and `address(this).delegatecall()`, should always be restricted with a struct.

2. It doesn't handles the fee mechanism well
As described in the `H-01` the fee mechanism for batch calls is broken. It will likely also break in the cases of when there is multiple recipients and one of the address is optimism public good address. The implementation of fee-mechanism will be really complicated. 

These are the two main issues which makes the batch functionality really bad & unnecassarily complicated. It is using assembely, delegatecall, function selectors, all things which should be only used when very necesaasry. This functionality can be easily implemented without going into many complications.

### Recommended Mitigation:
Add 4 simple functions in the TippingOP.sol; `batchSendTo()`, `batchSendTokenTo()`, `batchSendERC721To()` & `batchSendERC1155To()`. These functions should just do some looping and forward calls to the respective aleady implemented functions. 
- A simple `batchERC20To()` example: 
```solidity
    ///@audit-info Recommended Batch() Example
    function batchSendTokenTo(
        address[] _recipient,
        uint256[] _amount,
        address _tokenContractAddr,
        string memory _message
    ) external payable override {
        require(_recipient.length == _amount.length, "mismatch");
        for (uint i = 0; i < _amount.length; i++) {
            sendTokenTo(_recipient[i], _amount[i], _tokenContractAddr, _message);
        }
    }
```
This will help in better management of the fee-mechanism and lower the complexity of the code whcih means increased userability.

# Low Risk Findings
## L-01: Dangerous `payable` function: Users may accidentaly send Native coins and lose it
`SendTokenTo()` is a payable function whcih don't uses `msg.value`. Which means if a user accidentaly send eths to it, he'll lose it. Consider removiung the `payable` keyword:
```diff
    function sendTokenTo(
        address _recipient,
        uint256 _amount,
        address _tokenContractAddr,
        string memory _message
-    ) external payable override {
+    ) external override {
        (, uint256 paymentValue) = _splitPayment(_amount, AssetType.Token);
        if (publicGoods[_recipient]) {
            paymentValue = _amount;
            _attestDonor(_recipient);
        }
        _sendTokenAssetFrom(_amount, msg.sender, address(this), _tokenContractAddr);
        _sendTokenAsset(paymentValue, _recipient, _tokenContractAddr);

        emit TipMessage(_recipient, _message, msg.sender, _tokenContractAddr, _amount-paymentValue);
    }
```

## L-02: Revert conditions not handled well
The `batch()` function should handle calls for the correct function signatures, it should not allow any other type of call to the contract if the contract is not meant for tippping a asset. In the else condition below it should just simply revert:
```solidity
            if (isMsgValueOverride(sig)) {
                uint256 currentCallPriceAmount = calculateMsgValueForACall(sig, data);

                _MSG_VALUE = currentCallPriceAmount;
                msgValueSentAcc += currentCallPriceAmount;

                ///@audit-ok weird check - makes sense now
                ///@audit-ok batch call to SendTokenTo will cause users double fee - nope because its actually passing zero value
                ///@audit H this actually means: 0 <= msg.value - that mean fee for ERC721 & ERC1155 can be double spent
                require (msgValueSentAcc <= msg.value, "Can't send more than msg.value");

                (success, result) = address(this).delegatecall(data);

                _MSG_VALUE = 0;
            } else {
                ///@audit L i think it should not allow anyother type of call to the contract if the contract is not meant for tippping
                ///this shopuld simply revert the trx - reverts not handled well
                (success, result) = address(this).delegatecall(data);
            }
```
Same goes with the `calculateMsgValueForACall()`, it should not assume that if the function selector is unmatched to sendTo, sendTokenTo or sendERC721To, then its for sendERC1155To. It should check for the ERC1155's function selector as well in the else-if and in the else: simple revert the whole TRX
```solidity
    function calculateMsgValueForACall(bytes4 _selector, bytes memory _calldata) override view internal returns (uint256) {
        uint256 currentCallPriceAmount;

        if (_selector == this.sendTo.selector) {
            assembly {
                currentCallPriceAmount := mload(add(_calldata, 68))
            }
        } else if (_selector == this.sendTokenTo.selector) {
            currentCallPriceAmount = getPaymentFee(0, AssetType.Token);
        } else if (_selector == this.sendTokenTo.selector) {
            currentCallPriceAmount = getPaymentFee(0, AssetType.NFT);
        ///@audit-issue L this is not good, it should look for ERC1155 in the else-if and in the else: revert - reverts not handled well
        } else {
            currentCallPriceAmount = getPaymentFee(0, AssetType.ERC1155);
        }

        return currentCallPriceAmount;
    }
```

# Gas Findings
## G-01: Use `if/else` to check the public good address and setting the payment value
`sentTo()` & `sendTokenTo()` first calculate the whole payment value and then checks if the recipoient address is public good address or not and if the address is PGA then it set it to full, which is not a optimized way.
Not optimized way:
```solidity
        (, uint256 paymentValue) = _splitPayment(_amount, AssetType.Token);
        if (publicGoods[_recipient]) {
            paymentValue = _amount;
            _attestDonor(_recipient);
        }
```
- Gas Optimized Way:
```solidity
        
        if (publicGoods[_recipient]) {
            paymentValue = msgValue;
            _attestDonor(_recipient);
        } else {
            (, uint256 paymentValue) = _splitPayment(msgValue, AssetType.Coin);
        }
```

## G-02: Use custom errors instead of require/revert strings msgs
Custom errors are available from solidity version 0.8.4. Custom errors save ~50 gas each time they're hit by avoiding having to allocate and store the revert string. Not defining the strings also saves deployment gas.
There are 2 instances of this issue in the main contract:
```solidity
    function withdraw() external override onlyAdminCanWithdraw {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Failed to withdraw."); ///@audit G
    }
```
```solidity
    function renounceOwnership() public override view onlyOwner {
        revert("Operation not supported"); ///@audit G
    }
```


# Informational Findings
## I-01: Variable defined but not used/set
`contractOwner` is defined in the TippingOP.sol but it's not set or used anywhere. Consider using it or removing it. We would suggest the latter more.
```solidity
    ///@audit NC not used or set
    address public contractOwner;
```

## I-02: Dev commnets and param commnets missing
Consider adding dev commnets and param commnets to all the functions especially external/public functions. It increases the code readiablity anjd auditability

## I-03: Use reentrancy locks/gaurds
There is no such instance found where reentrancy locks is neccassary but using a reentrancyGaurd can be really helpful especially dealing with the hooks of ERC777 Tokens (ERC20 Compatibl;e Tokens) and safeTranfers of ERC721. 

## I-04: Take fees in Native coins for the ERC20 as well or consider using a ERC20 Tokens Whitelist
Some projects can distribute shitcoins which will be worthless for the protocol or use a whitelist, if the token is in the whitelist then take fee from ERC20 otherwise in native coins

## I-05: Use Named imports consistently
Consider adding names to the imports of external libraries as well
```solidity
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ITipping } from "./interfaces/ITipping.sol";
```

## I-06: Contract & File name mismatch
Consider naming contract & file name exact same. The `TippingOP.sol` file name and contracts name `TippingPG` mismatches

## I-07: Wrong Comment
`sendERC1155To()`'s dev notice comment is wrong:
```diff
    /**
     * ///@audit NC wrong dev comment - it should be "Send a tip in ERC1155 token"
-    * @notice Send a tip in ERC721 token, charging a small $ fee
+    * @notice Send a tip in ERC1155 token, charging a small $ fee
     */
    function sendERC1155To(){}
 ```