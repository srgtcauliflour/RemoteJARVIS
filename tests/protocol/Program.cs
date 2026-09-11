int total = 0;
int failed = 0;
ProtocolChecks.Run((passed, name) =>
{
    total++;
    if (!passed) failed++;
    Console.WriteLine($"[{(passed ? "pass" : "FAIL")}] {name}");
});
Console.WriteLine($"Protocol checks: {total - failed}/{total} passed.");
return total > 0 && failed == 0 ? 0 : 1;
