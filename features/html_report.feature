Feature: HTML Report
  In order to know which exact lines are being executed
  And to explore our source code
  I want a persistant coverage report in HTML

  Background:
    Given a file named "public/javascripts/foo.js" with:
    """
    // this is a comment

    var one = "foo";                  // 1
    var z = 0;                        // 2

    var two = function () {           // 3
      for (var i = 0; i < 10; i++) {  // 4
        z++;                          // 5
      }
    };

    function three() {                // 6
      two();                          // 7
    }

    """

    And a file named "public/javascripts/bar.js" with:
    """
    var foo = 1;
    var bar = 2;
    var baz = 3;
    """

    And a file named "test/javascripts/runner.js" with:
    """
    load("public/javascripts/foo.js");
    load("public/javascripts/bar.js");
    error_count = 0;
    """

  Scenario: reports to an HTML file
    When I run `jcov --report`
    Then a file named "jcov/report.html" should exist

  Scenario: reports individual files to their own HTML files
    When I run `jcov --report`
    Then a file named "jcov/public/javascripts/foo.js.html" should exist
    Then a file named "jcov/public/javascripts/bar.js.html" should exist

  Scenario: it copies a css file
    When I run `jcov --report`
    Then a file named "jcov/report.css" should exist

  Scenario: has a list of ran files
    When I run `jcov --report`
    And I open the report
    Then I should see "public/javascripts/foo.js (4/7) 57%"
    And I should see "public/javascripts/bar.js (3/3) 100%"

  Scenario: shows the total coverage
    When I run `jcov --report`
    And I open the report
    And I should see "Total: (7/10) 70%"

  Scenario: shows the total coverage in the title
    When I run `jcov --report`
    And I open the report
    And I should see "JCov : 70%"

  Scenario: shows empty source files
    Given a file named "public/javascripts/foo.js" with:
    """
    // this is a comment
    """
    When I run `jcov --report`
    And I open the report
    Then I should see "public/javascripts/foo.js (EMPTY) 100%"

  Scenario: click through to an individual file's report
    When I run `jcov --report`
    And I open the report
    And I click "public/javascripts/foo.js"
    Then I should see "public/javascripts/foo.js"

  Scenario: can click back to the index
    When I run `jcov --report`
    And I open the report
    And I click "public/javascripts/foo.js"
    And I click "JCov"
    Then I should be on /report.html

  Scenario: see a file-level coverage percentage
    When I run `jcov --report`
    And I open the report
    And I click "public/javascripts/foo.js"
    Then I should see "57%"

  Scenario: see covered lines
    When I run `jcov --report`
    And I open the report
    And I click "public/javascripts/foo.js"
    Then I should see these lines covered:
      | line                      |
      | var one = "foo";          |
      | var z = 0;                |
      | var two = function () {   |
      | function three() {        |

  Scenario: see uncovered lines
    When I run `jcov --report`
    And I open the report
    And I click "public/javascripts/foo.js"
    Then I should see these lines not covered:
      | line                           |
      | for (var i = 0; i < 10; i++) { |
      | z++;                           |
      | two();                         |

  Scenario: see uncoverable lines
    When I run `jcov --report`
    And I open the report
    And I click "public/javascripts/foo.js"
    Then I should see these lines uncoverable:
      | line                           |
      | // this is a comment           |

  Scenario: it escapes HTML entities
    When I run `jcov --report`
    And I open the report
    And I click "public/javascripts/foo.js"
    Then I should see "for (var i = 0; i &lt; 10; i++)" in the HTML
