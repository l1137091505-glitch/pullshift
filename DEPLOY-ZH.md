# PULLSHIFT 部署步骤

1. 在 GitHub 新建空的公开仓库 `pullshift`，不要额外创建 README、License 或 `.gitignore`。
2. 上传解压后的全部内容。
3. Vercel 导入仓库：Root Directory 选 `frontend`，Framework Preset 选 Vite。
4. 完成第一次预览部署。
5. Remix 新建 `Pullshift.sol`，粘贴 `contracts/src/Pullshift.sol` 全部内容。
6. Solidity Compiler 选择 0.8.24，编译 `Pullshift.sol`。
7. Deploy & Run Transactions 选择 Browser Extension / MetaMask，并切换 BOT Chain（Chain ID 677）。
8. 选择 `Pullshift - Pullshift.sol`，点击 Deploy；构造函数没有参数。
9. 复制合约地址，在 Vercel 添加：
   - Type：Config
   - Key：`VITE_PULLSHIFT_ADDRESS`
   - Value：完整合约地址
   - Environment：Production
10. 保存后重新部署 Production，不使用旧 Build Cache。

## 交互

1. CONNECT WALLET。
2. 选择 EMBER 或 TIDE。
3. 选择 0.001、0.005、0.01 BOT，或填写自定义金额。
4. 点击 LOCK & PULL，在钱包确认。
5. 倒计时结束后任何人可点击 SETTLE ROUND。
6. 胜方点击 CLAIM WINNINGS；平局时双方取回原投入。
7. 结算后任何人可点击 OPEN NEXT ROUND。

每次投入会把倒计时重置为 4 小时，但整轮最长不超过 48 小时。原生 BOT 进入合约后，输方无法取回。项目未经专业安全审计，请仅用少量 BOT 测试。