module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\.spec\.ts$',
  transform: {
    '^.+\.ts$': 'ts-jest',
  },
  collectCoverageFrom: ['**/*.service.ts', '!**/*.module.ts', '!**/main.ts'],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
    '^otplib$': '<rootDir>/testing/otplib.stub.ts',
    '^qrcode$': '<rootDir>/testing/qrcode.stub.ts',
  },
  workerIdleMemoryLimit: '512MB',
};
