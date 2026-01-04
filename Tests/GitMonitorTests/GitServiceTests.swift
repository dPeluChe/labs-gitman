import XCTest
@testable import GitMonitor

class GitServiceTests: XCTestCase {
    
    // We cannot easily mock the ProcessExecutor in a unit test without more refactoring (DI),
    // so we will test the public API with non-destructive methods or basic logic.
    // Ideally, we would refactor GitService to accept a 'ProcessExecutorProtocol' for mocking.
    
    func testDependencyChecking() async {
        let service = GitService()
        let missing = await service.checkDependencies()
        
        // This test depends on the environment, but it sanity checks the code runs.
        // If git is missing, it should report it.
        // We assume the dev env has git.
        
        let gitMissing = missing.contains { 
            if case .missingGit = $0 { return true }
            return false
        }
        
        XCTAssertFalse(gitMissing, "Git should be installed in the test environment")
    }
    
    func testGitRepoDetection() {
        let service = GitService()
        // Use the project's own path which we know is a git repo (or has .git)
        // We need an absolute path. Let's try to get one dynamic or use a temp one.
        
        let tempDir = FileManager.default.temporaryDirectory
        let isRepo = service.isGitRepository(at: tempDir.path)
        XCTAssertFalse(isRepo, "Temp dir should not be a git repo")
        
        // Note: Testing positive case requires creating a real .git folder
    }
}
