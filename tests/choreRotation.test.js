import test from 'node:test';
import assert from 'node:assert/strict';
import { nextVacuumMember } from '../src/choreRotation.js';
const members = ['a','b','c','d'].map(user_id => ({user_id}));
test('no roommate', () => assert.equal(nextVacuumMember([],null),null));
test('first vacuum goes to first member', () => assert.equal(nextVacuumMember(members,null).user_id,'a'));
test('vacuum rotates among four and wraps', () => {
  for (let i=0;i<4;i++) assert.equal(nextVacuumMember(members,{member_id:members[i].user_id}).user_id,members[(i+1)%4].user_id);
});
test('removed last member falls back to first', () => assert.equal(nextVacuumMember(members,{member_id:'removed'}).user_id,'a'));
