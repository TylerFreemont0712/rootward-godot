extends GdUnitTestSuite
## A C++ card is counted on its own lines (ADR-0046): loops and functions gain a counter, and nothing else moves.


func test_a_loop_with_a_brace_counts_on_entering_its_body() -> void:
	var line := CppSource.instrument("  for (Bolt& bolt : bolts) {")
	assert_str(line).is_equal("  for (Bolt& bolt : bolts) { ROOTWARD_LOOP();")


func test_a_one_statement_loop_gains_braces_on_its_line() -> void:
	var line := CppSource.instrument("  for (Bolt& bolt : bolts) bolt.power += 3;")
	assert_str(line).is_equal("  for (Bolt& bolt : bolts) { ROOTWARD_LOOP(); bolt.power += 3; }")


func test_a_while_and_a_nested_header_count_too() -> void:
	assert_str(CppSource.instrument("while (lo < hi) {")).is_equal("while (lo < hi) { ROOTWARD_LOOP();")
	var nested := CppSource.instrument("for (int s = f(a, (b)); s >= x; s--) {")
	assert_str(nested).is_equal("for (int s = f(a, (b)); s >= x; s--) { ROOTWARD_LOOP();")


func test_a_function_counts_its_calls_and_an_if_does_not() -> void:
	var code := "Bolts divide(Bolts bolts, const Battle& battle) {\n  if (bolts.size() <= 1) {\n    return bolts;\n  }"
	var lines := CppSource.instrument(code).split("\n")
	assert_str(lines[0]).is_equal('Bolts divide(Bolts bolts, const Battle& battle) { ROOTWARD_CALL("divide");')
	assert_str(lines[1]).is_equal("  if (bolts.size() <= 1) {")
	assert_int(lines.size()).is_equal(4)


func test_comments_are_kept_and_never_instrumented() -> void:
	var line := CppSource.instrument("  // for (a loop in a comment) {")
	assert_str(line).is_equal("  // for (a loop in a comment) {")
	var after := CppSource.instrument("  for (int i = 0; i < n; i++) {  // every bolt")
	assert_str(after).is_equal("  for (int i = 0; i < n; i++) { ROOTWARD_LOOP();  // every bolt")


func test_a_unit_puts_the_card_in_its_own_namespace_at_its_own_lines() -> void:
	var unit := CppSource.unit("fib-memo~3", "Bolts fib_memo(Bolts bolts, const Battle& battle) {\n}", "program.hpp")
	assert_str(unit).contains('#include "program.hpp"')
	assert_str(unit).contains("namespace card_fib_memo_3 {")
	assert_str(unit).contains('#line 1 "fib-memo.cpp"')
