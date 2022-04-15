@echo off
call yarn init
call yarn add truffle --dev
call yarn add @openzeppelin/contracts@3.4.2-solc-0.7 --dev
call yarn add ganache-cli --dev
call yarn add chai --dev
call yarn add @openzeppelin/test-helpers --dev
call yarn add @chainlink/contracts --dev
call npx truffle init