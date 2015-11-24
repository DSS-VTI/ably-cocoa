//
//  RestClient.swift
//  ably
//
//  Created by Yavor Georgiev on 2.08.15.
//  Copyright © 2015 г. Ably. All rights reserved.
//

import Nimble
import Quick

import ably
import ably.Private

class RestClient: QuickSpec {
    override func spec() {

        var mockExecutor: MockHTTPExecutor!

        beforeEach {
            mockExecutor = MockHTTPExecutor()
        }

        describe("RestClient") {
            // RSC1
            context("initializer") {
                it("should accept an API key") {
                    let options = AblyTests.commonAppSetup()
                    
                    let client = ARTRest(key: options.key!)
                    client.baseUrl = options.restUrl()

                    let publishTask = publishTestMessage(client)

                    expect(publishTask.error).toEventually(beNil(), timeout: testTimeout)
                }

                it("should throw when provided an invalid key") {
                    expect{ ARTRest(key: "invalid_key") }.to(raiseException())
                }

                it("should result in error status when provided a bad key") {
                    let client = ARTRest(key: "bad")

                    let publishTask = publishTestMessage(client, failOnError: false)

                    expect(publishTask.error?.domain).toEventually(equal(ARTAblyErrorDomain), timeout: testTimeout)
                    expect(publishTask.error?.code).toEventually(equal(40005))
                }

                it("should accept an options object") {
                    let options = AblyTests.commonAppSetup()
                    let client = ARTRest(options: options)

                    let publishTask = publishTestMessage(client)

                    expect(publishTask.error).toEventually(beNil(), timeout: testTimeout)
                }

                it("should accept an options object with token authentication") {
                    let options = AblyTests.commonAppSetup()
                    options.token = getTestToken()
                    let client = ARTRest(options: options)

                    let publishTask = publishTestMessage(client)

                    expect(publishTask.error).toEventually(beNil(), timeout: testTimeout)
                }

                it("should result in error status when provided a bad token") {
                    let options = AblyTests.commonAppSetup()
                    options.token = "invalid_token"
                    let client = ARTRest(options: options)

                    let publishTask = publishTestMessage(client, failOnError: false)

                    expect(publishTask.error?.domain).toEventually(equal(ARTAblyErrorDomain), timeout: testTimeout)
                    expect(publishTask.error?.code).toEventually(equal(40005), timeout: testTimeout)
                }
            }

            context("logging") {
                // RSC2
                it("should output to the system log and the log level should be Warn") {
                    let logTime = NSDate()
                    let client = ARTRest(options: AblyTests.commonAppSetup())

                    client.logger.log("This is a warning", withLevel: .Warn)
                    let logs = querySyslog(forLogsAfter: logTime)

                    expect(client.logger.logLevel).to(equal(ARTLogLevel.Warn))
                    expect(logs).to(contain("WARN: This is a warning"))
                }

                // RSC3
                it("should have a mutable log level") {
                    let logTime = NSDate()
                    let client = ARTRest(options: AblyTests.commonAppSetup())
                    client.logger.logLevel = .Error

                    client.logger.log("This is a warning", withLevel: .Warn)
                    let logs = querySyslog(forLogsAfter: logTime)

                    expect(logs).toNot(contain("WARN: This is a warning"))
                }

                // RSC4
                it("should accept a custom logger") {
                    struct Log {
                        static var interceptedLog: (String, ARTLogLevel) = ("", .None)
                    }
                    class MyLogger : ARTLog {
                        override func log(message: String, withLevel level: ARTLogLevel) {
                            Log.interceptedLog = (message, level)
                        }
                    }

                    let options = AblyTests.commonAppSetup()
                    let customLogger = MyLogger()
                    customLogger.logLevel = .Verbose
                    let client = ARTRest(logger: customLogger, andOptions: options)

                    client.logger.log("This is a warning", withLevel: .Warn)
                    
                    expect(Log.interceptedLog.0).to(equal("This is a warning"))
                    expect(Log.interceptedLog.1).to(equal(ARTLogLevel.Warn))
                    
                    expect(client.logger.logLevel).to(equal(customLogger.logLevel))
                }
            }

            // RSC11
            context("endpoint") {
                it("should accept an options object with a host set") {
                    let options = ARTClientOptions(key: "fake:key")
                    options.environment = "fake"
                    let client = ARTRest(options: options)
                    client.httpExecutor = mockExecutor
                    
                    publishTestMessage(client, failOnError: false)
                    
                    expect(mockExecutor.requests.first?.URL?.host).toEventually(equal("fake.ably.host"), timeout: testTimeout)
                }
                
                it("should accept an options object with an environment set") {
                    let options = ARTClientOptions(key: "fake:key")
                    options.environment = "myEnvironment"
                    let client = ARTRest(options: options)
                    client.httpExecutor = mockExecutor
                    
                    publishTestMessage(client, failOnError: false)
                    
                    expect(mockExecutor.requests.first?.URL?.host).toEventually(equal("myEnvironment-rest.ably.io"), timeout: testTimeout)
                }
                
                it("should default to https://rest.ably.io") {
                    let options = ARTClientOptions(key: "fake:key")
                    let client = ARTRest(options: options)
                    client.httpExecutor = mockExecutor
                    
                    publishTestMessage(client, failOnError: false)
                    
                    expect(mockExecutor.requests.first?.URL?.absoluteString).toEventually(beginWith("https://rest.ably.io"), timeout: testTimeout)
                }
                
                it("should connect over plain http:// when tls is off") {
                    let options = ARTClientOptions(key: "fake:key")
                    options.tls = false;
                    let client = ARTRest(options: options)
                    client.httpExecutor = mockExecutor
                    
                    publishTestMessage(client, failOnError: false)
                    
                    expect(mockExecutor.requests.first?.URL?.scheme).toEventually(equal("http"), timeout: testTimeout)
                }
            }

            // RSC5
            it("should provide access to the AuthOptions object passed in ClientOptions") {
                let options = AblyTests.setupOptions(AblyTests.jsonRestOptions)
                let client = ARTRest(options: options)
                
                let authOptions = client.auth.options
                
                expect(authOptions).to(beIdenticalTo(options))
            }
            
            // RSC16
            context("time") {
                it("should return server time") {
                    let options = AblyTests.setupOptions(AblyTests.jsonRestOptions)
                    let client = ARTRest(options: options)
                    
                    var time: NSDate?
                    
                    client.time({ date, error in
                        time = date
                    })
                    
                    expect(time?.timeIntervalSince1970).toEventually(beCloseTo(NSDate().timeIntervalSince1970, within: 60), timeout: testTimeout)
                }
            }

            // RSC7, RSC18
            it("should send requests over http and https") {
                let options = AblyTests.commonAppSetup()

                let clientHttps = ARTRest(options: options)
                clientHttps.httpExecutor = mockExecutor

                options.clientId = "client_http"
                options.tls = false
                let clientHttp = ARTRest(options: options)
                clientHttp.httpExecutor = mockExecutor

                publishTestMessage(clientHttps)
                publishTestMessage(clientHttp)

                if let requestUrlA = mockExecutor.requests.first?.URL,
                   let requestUrlB = mockExecutor.requests.last?.URL {
                    expect(requestUrlA.scheme).to(equal("https"))
                    expect(requestUrlB.scheme).to(equal("http"))
                }
            }

            // RSC9
            it("should use Auth to manage authentication") {
                let options = AblyTests.commonAppSetup()
                let client = ARTRest(options: options)
                let auth = client.auth

                expect(auth.method.rawValue).to(equal(ARTAuthMethod.Basic.rawValue))

                waitUntil(timeout: 25.0) { done in
                    auth.requestToken(nil, withOptions: options, callback: { tokenDetailsA, errorA in
                        if let e = errorA {
                            XCTFail(e.description)
                            done()
                        }
                        else if let currentTokenDetails = tokenDetailsA {
                            auth.setTokenDetails(currentTokenDetails)
                        }

                        auth.authorise(nil, options: options, force: false, callback: { tokenDetailsB, errorB in
                            if let e = errorB {
                                XCTFail(e.description)
                                done()
                            }
                            // Use the same token because it is valid
                            expect(auth.tokenDetails?.token).to(equal(tokenDetailsB?.token))
                            done()
                        })
                    })
                }
            }

            // RSC10
            it("should request another token after current one is no longer valid") {
                let options = AblyTests.commonAppSetup()
                let client = ARTRest(options: options)
                let auth = client.auth

                let tokenParams = ARTAuthTokenParams()
                tokenParams.ttl = 3.0 //Seconds

                waitUntil(timeout: 25.0) { done in
                    auth.requestToken(tokenParams, withOptions: options) { tokenDetailsA, errorA in
                        if let e = errorA {
                            XCTFail(e.description)
                            done()
                        }
                        else if let currentTokenDetails = tokenDetailsA {
                            auth.setTokenDetails(currentTokenDetails)
                        }

                        // Delay for token expiration
                        delay(tokenParams.ttl) {
                            auth.authorise(tokenParams, options: options, force: false) { tokenDetailsB, errorB in
                                if let e = errorB {
                                    XCTFail(e.description)
                                    done()
                                }
                                // Different token
                                expect(tokenDetailsA?.token).toNot(equal(tokenDetailsB?.token))
                                done()
                            }
                        }
                    }
                }
            }

            // RSC14b
            context("basic authentication flag") {
                it("should be true when key is set") {
                    let client = ARTRest(key: "key:secret")
                    expect(client.auth.options.isBasicAuth()).to(beTrue())
                }

                for (caseName, caseSetter) in AblyTests.authTokenCases {
                    it("should be false when \(caseName) is set") {
                        let options = ARTClientOptions()
                        caseSetter(options)

                        let client = ARTRest(options: options)

                        expect(client.auth.options.isBasicAuth()).to(beFalse())
                    }
                }
            }

            // RSC14c
            it("should error when expired token and no means to renew") {
                let client = ARTRest(options: AblyTests.commonAppSetup())
                let auth = client.auth

                let tokenParams = ARTAuthTokenParams()
                tokenParams.ttl = 3.0 //Seconds

                waitUntil(timeout: testTimeout) { done in
                    auth.requestToken(tokenParams, withOptions: nil) { tokenDetails, error in
                        if let e = error {
                            XCTFail(e.description)
                            done()
                        }
                        else if let currentTokenDetails = tokenDetails {
                            let options = AblyTests.clientOptions()
                            options.key = client.options.key

                            // Expired token
                            options.tokenDetails = ARTAuthTokenDetails(token: currentTokenDetails.token, expires: currentTokenDetails.expires?.dateByAddingTimeInterval(testTimeout), issued: currentTokenDetails.issued, capability: currentTokenDetails.capability, clientId: currentTokenDetails.clientId)

                            options.authUrl = NSURL(string: "http://test-auth.ably.io")

                            let rest = ARTRest(options: options)
                            rest.httpExecutor = mockExecutor

                            // Delay for token expiration
                            delay(tokenParams.ttl) {
                                // 40140 - token expired and will not recover because authUrl is invalid
                                publishTestMessage(rest) { error in
                                    expect(mockExecutor.responses.first?.allHeaderFields["X-Ably-ErrorCode"] as? String).to(equal("40140"))
                                    expect(error).toNot(beNil())
                                    done()
                                }
                            }
                        }
                    }
                }
            }

            // RSC14d
            it("should renew the token when it has expired") {
                let client = ARTRest(options: AblyTests.commonAppSetup())
                let auth = client.auth

                let tokenParams = ARTAuthTokenParams()
                tokenParams.ttl = 3.0 //Seconds

                waitUntil(timeout: testTimeout) { done in
                    auth.requestToken(tokenParams, withOptions: nil) { tokenDetails, error in
                        if let e = error {
                            XCTFail(e.description)
                            done()
                        }
                        else if let currentTokenDetails = tokenDetails {
                            let options = AblyTests.clientOptions()
                            options.key = client.options.key

                            // Expired token
                            options.tokenDetails = ARTAuthTokenDetails(token: currentTokenDetails.token, expires: currentTokenDetails.expires?.dateByAddingTimeInterval(testTimeout), issued: currentTokenDetails.issued, capability: currentTokenDetails.capability, clientId: currentTokenDetails.clientId)

                            let rest = ARTRest(options: options)
                            rest.httpExecutor = mockExecutor

                            // Delay for token expiration
                            delay(tokenParams.ttl) {
                                // 40140 - token expired and will resend the request
                                publishTestMessage(rest) { error in
                                    expect(mockExecutor.responses.first?.allHeaderFields["X-Ably-ErrorCode"] as? String).to(equal("40140"))
                                    expect(error).to(beNil())
                                    expect(rest.auth.tokenDetails?.token).toNot(equal(currentTokenDetails.token))
                                    done()
                                }
                            }
                        }
                    }
                }
            }

        } //RestClient
    }
}