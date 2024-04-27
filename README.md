# 测试方法

1、安装nodejs
https://nodejs.org/

2、安装hardhat
```shell
npm install --save-dev hardhat 或者 yarn add --dev hardhat
```
3、运行测试用例
```shell
npx hardhat test
```

4、其他说明
- 测试用例：test/basic_contract_test.js
- 合约文件：contracts/CarPooling.sol
- 合约和测试用例有中文描述，请酌情修改，另外合约注释很清晰方便你理解，但提交给学校的时候建议稍微删减