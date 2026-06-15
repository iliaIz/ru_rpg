const test = require('node:test');
const assert = require('node:assert/strict');

const FormulaEvaluator = require('../public/js/formula-evaluator.js');

test('normalizeVariableKey keeps non-Latin (Cyrillic) letters so localized names yield valid keys', () => {
    assert.equal(
        FormulaEvaluator.normalizeVariableKey('Знание Городской Навигации'),
        'знание_городской_навигации'
    );
    assert.equal(FormulaEvaluator.normalizeVariableKey('Сила'), 'сила');
    assert.equal(FormulaEvaluator.normalizeVariableKey('42 Меча'), '42_меча');
});

test('normalizeVariableKey still normalizes English names as before', () => {
    assert.equal(FormulaEvaluator.normalizeVariableKey('Two-Handed Weapons'), 'two_handed_weapons');
    assert.equal(FormulaEvaluator.normalizeVariableKey('Lockpicking'), 'lockpicking');
});

test('normalizeVariableKey still rejects keys with no letters or digits', () => {
    assert.throws(
        () => FormulaEvaluator.normalizeVariableKey('***'),
        /has no alphanumeric characters/
    );
    assert.throws(
        () => FormulaEvaluator.normalizeVariableKey('   '),
        /Variable key cannot be empty/
    );
});
