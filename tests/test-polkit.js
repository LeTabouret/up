// Exercise rule behavior with Polkit's small API surface, without changing host policy.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
let rule;
vm.runInNewContext(fs.readFileSync(path.join(__dirname,
    '../usr/share/polkit-1/rules.d/00-up-admin-helpers.rules'), 'utf8'), {
    polkit: {addRule: fn => { rule = fn; }, Result: {AUTH_ADMIN: 'auth_admin'}}
});
const actions = [
    'org.bazzite.policykit.privileged.user.setup',
    'org.bazzite.policykit.waydroid.container.start',
    'org.bazzite.policykit.waydroid.container.stop',
    'org.bazzite.policykit.waydroid.container.restart',
    'org.bazzite.policykit.waydroid.fix.controllers'
];
for (const id of actions) {
    for (const subject of [{active: true, local: true}, {active: false, local: false}]) {
        assert.equal(rule({id}, subject), 'auth_admin', id);
    }
}
assert.equal(rule({id: 'org.freedesktop.udisks2.filesystem-mount'}, {}), undefined);
assert.equal(rule({id: 'org.bazzite.policykit.waydroid.unrelated'}, {}), undefined);
console.log('Polkit helper authentication tests passed.');
