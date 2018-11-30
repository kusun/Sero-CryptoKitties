# Sero-CryptoKitties
Anonymous version of CryptoKitties

Sero-CryptoKitties is base on [SERO](https://sero.cash/),that has the same characteristics as cryptokitties which base  on Etherenum.This is a tentative project to test if the [SERO](https://sero.cash/) supports smart contracts.
nd the conclusion is that an anonymous version of CryptoKitties can be implemented by SERO. 


The project is based on [awesome-cryptokitties](https://github.com/cryptocopycats/awesome-cryptokitties) source code，the main change is how to use SeroInterface.sol. SeroInterface is a system interface provided by the  [SERO](https://sero.cash/)  team in its IDE([remix](http://remix.web.sero.cash)), which is the underlying interface for implementing an anonymous version of a smart contract.

Some methods and properties are removed in this project, which SERO does not need.And mixGenes function uses only one random function instead.