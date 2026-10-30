const luaparse = require('luaparse');
const fs = require('fs');

const files = [
  'KUICooldownManager.lua',
  'KUI_CooldownManager_Options.lua'
];

for (const file of files) {
  try {
    const code = fs.readFileSync(file, 'utf8');
    luaparse.parse(code);
    console.log(`✅ ${file}: Syntax OK`);
  } catch (err) {
    console.error(`❌ ${file}: Syntax Error:\n${err.message}`);
  }
}
