import XCTest
@testable import GitMonitor

/// Unit tests for GitService
final class GitServiceTests: XCTestCase {

    var gitService: GitService!

    override func setUp() async throws {
        gitService = GitService()
    }

    override func tearDown() async throws {
        gitService = nil
    }

    // MARK: - Repository Detection Tests

    func testIsGitRepository_ValidRepo() async throws {
        // Test with a known git repository
        let isRepo = await gitService.isGitRepository(at: "/Users/peluche/dPeluCheData/PROJECTS/dPeluChe/_code_/labs-gitman")
        XCTAssertTrue(isRepo, "Should detect valid git repository")
    }

    func testIsGitRepository_InvalidRepo() async throws {
        // Test with a non-git directory
        let tempDir = FileManager.default.temporaryDirectory
        let isRepo = await gitService.isGitRepository(at: tempDir.path)
        XCTAssertFalse(isRepo, "Should not detect non-git directory as repository")
    }

    // MARK: - Branch Switching Tests

    func testSwitchBranch_UncommittedChanges() async throws {
        // This test verifies that switching branches fails with uncommitted changes
        // We can't easily test this without a real repo with uncommitted changes
        // but we can test the error handling

        let gitService = GitService()

        do {
            try await gitService.switchBranch(
                path: "/fake/path",
                branchName: "main"
            )
            XCTFail("Should throw error for non-existent path")
        } catch {
            // Expected to throw
            XCTAssertTrue(error is GitService.GitError)
        }
    }

    // MARK: - Commit History Tests

    func testGetCommitHistory_ValidRepo() async throws {
        let commits = try await gitService.getCommitHistory(
            path: "/Users/peluche/dPeluCheData/PROJECTS/dPeluChe/_code_/labs-gitman",
            limit: 5
        )

        XCTAssertFalse(commits.isEmpty, "Should return commits")
        XCTAssertLessThanOrEqual(commits.count, 5, "Should return at most limit commits")

        // Verify commit structure
        if let firstCommit = commits.first {
            XCTAssertFalse(firstCommit.hash.isEmpty, "Commit should have hash")
            XCTAssertFalse(firstCommit.author.isEmpty, "Commit should have author")
            XCTAssertFalse(firstCommit.message.isEmpty, "Commit should have message")
            XCTAssertNotNil(firstCommit.date, "Commit should have date")
        }
    }

    func testGetCommitHistory_InvalidRepo() async throws {
        do {
            _ = try await gitService.getCommitHistory(
                path: "/fake/nonexistent/path",
                limit: 10
            )
            XCTFail("Should throw error for non-existent path")
        } catch {
            // Expected to throw
            XCTAssertTrue(true)
        }
    }

    // MARK: - GitStatus Tests

    func testGetStatus_ValidRepo() async throws {
        let project = Project(
            path: "/Users/peluche/dPeluCheData/PROJECTS/dPeluChe/_code_/labs-gitman"
        )

        let status = try await gitService.getStatus(for: project)

        XCTAssertNotNil(status, "Should return status")
        XCTAssertFalse(status.currentBranch.isEmpty, "Should have current branch")
    }

    // MARK: - Performance Tests

    func testPerformance_GetCommitHistory() async throws {
        measure {
            let expectation = expectation(description: "Get commit history")

            Task {
                try? await gitService.getCommitHistory(
                    path: "/Users/peluche/dPeluCheData/PROJECTS/dPeluChe/_code_/labs-gitman",
                    limit: 50
                )
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }
}
