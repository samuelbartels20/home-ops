#!/usr/bin/env node

const { execSync } = require('child_process');

function generateDateVersion() {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  const day = String(now.getUTCDate()).padStart(2, '0');
  return `${year}.${month}.${day}`;
}

function getExistingVersions() {
  try {
    const tags = execSync('git tag -l "v*"', { encoding: 'utf8' })
      .split('\n')
      .filter(tag => tag.trim())
      .map(tag => tag.replace(/^v/, ''))
      .filter(version => /^\d{4}\.\d{2}\.\d{2}(\.\d+)?$/.test(version));

    return tags;
  } catch (error) {
    console.error('No existing tags found or error reading tags');
    return [];
  }
}

function getNextVersion(baseVersion, existingVersions) {
  if (!existingVersions.includes(baseVersion)) {
    return baseVersion;
  }

  // If version exists, append a revision number
  let revision = 1;
  let nextVersion = `${baseVersion}.${revision}`;

  while (existingVersions.includes(nextVersion)) {
    revision++;
    nextVersion = `${baseVersion}.${revision}`;
  }

  return nextVersion;
}

const baseVersion = generateDateVersion();
const existingVersions = getExistingVersions();
const nextVersion = getNextVersion(baseVersion, existingVersions);

console.log(nextVersion);