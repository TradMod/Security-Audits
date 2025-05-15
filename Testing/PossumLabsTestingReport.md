Unit/Fork Testing caught 1 High, 1 Medium & 1 Low security vulnerabilities. 
- HIGH: migrateStake() deletes the msg.sender's accounts data instead of user's. 
- MEDIUM: Transfer user's inputted amount instaed of actual recieved amount
- LOW: Dangerous Payable Function

PR: https://github.com/PossumLabsCrypto/Adapters/pull/2

Test Coverage Updated up to 70%. All Tests Pass:
```js
$ forge test --fork-url $ARB_MAINNET_RPC_URL 
[⠆] Compiling...
No files changed, compilation skipped

Running 45 tests for test/AdapterV1Test.t.sol:AdapterV1Test
[PASS] testBurnPortalEnergyToken() (gas: 409237)
[PASS] testBuyPortalEnergy() (gas: 165073)
[PASS] testBuyPortalEnergy_MultipleUsers() (gas: 397132)
[PASS] testFailBurnPortalEnergyToken_InvalidAddr() (gas: 406177)    
[PASS] testFailBurnPortalEnergyToken_NotEnoughTokens() (gas: 406117)
[PASS] testFailBuyPortalEnergy_NotEnoughBal() (gas: 98667)
[PASS] testFailBuyPortalEnergy_zeroAddr() (gas: 201628)
[PASS] testFailSellPortalEnergy_DeadlineExpired() (gas: 213983)
[PASS] testFailSellPortalEnergy_ZeroAddr() (gas: 365541)
[PASS] testFailSellPortalEnergy_ZeroAmt() (gas: 272603)
[PASS] testMigrateStake() (gas: 878099)
[PASS] testMintPortalEnergyToken() (gas: 298668)
[PASS] testMintPortalEnergyToken_NotEnoughEnergy() (gas: 171516)
[PASS] testProposeMigrationDestination() (gas: 37559)
[PASS] testRevertsBurnPortalEnergyToken_InvalidAmt() (gas: 334205)
[PASS] testRevertsBuyPortalEnergy_zeroAmt() (gas: 98290)
[PASS] testRevertsMintPortalEnergyToken_InvalidAddr() (gas: 205574)
[PASS] testRevertsMintPortalEnergyToken_InvalidAmt() (gas: 205641)
[PASS] testRevertsSellPortalEnergy_ModeInvalid() (gas: 166996)
[PASS] testRevertsSellPortalEnergy_NotEnoughEnergy() (gas: 173200)
[PASS] testRevertsStake_ETH() (gas: 330659)
[PASS] testRevertsStake_USDC() (gas: 358553)
[PASS] testRevertsStake_whenMigrationStarted() (gas: 361330)
[PASS] testRevertsUnstakeETH_InsufficientStakeBalance() (gas: 764225)
[PASS] testRevertsUnstakeUSDC_InsufficientStakeBalance() (gas: 762614)
[PASS] testReverts_ProposeMigrationDestination_notOwner() (gas: 11347)
[PASS] testReverts_migrateStake_migrationVotePending() (gas: 784784)
[PASS] testReverts_migrateStake_notCalledByDestination() (gas: 952332)
[PASS] testSellPortalEnergy_ModeOne() (gas: 254)
[PASS] testSellPortalEnergy_ModeTwo() (gas: 275)
[PASS] testSellPortalEnergy_ModeZero() (gas: 297374)
[PASS] testSetUp() (gas: 2508843)
[PASS] testStakeETH_totalPrincipalStakedIncreased() (gas: 1124060)
[PASS] testStake_ETH() (gas: 762554)
[PASS] testStake_ETH_2() (gas: 762628)
[PASS] testStake_USDC() (gas: 764971)
[PASS] testStake_USDC_DangerousPayableFunction_PoC() (gas: 772059)
[PASS] testUnstakeETH() (gas: 728756)
[PASS] testUnstakeETH_AfterVoting() (gas: 1253124)
[PASS] testUnstakeETH_burnPE() (gas: 920497)
[PASS] testUnstakeETH_totalPrincipalStakedDecreased() (gas: 730575)
[PASS] testUnstakeUSDC() (gas: 762036)
[PASS] testacceptMigrationDestination() (gas: 952145)
[PASS] testacceptMigrationDestination_ThreeUsersMajorityVotes() (gas: 1349281)
[PASS] testacceptMigrationDestination_ThreeUsersMinorityVote() (gas: 1208609)
Test result: ok. 45 passed; 0 failed; 0 skipped; finished in 32.55s

Ran 1 test suites: 45 tests passed, 0 failed, 0 skipped (45 total tests)
```