#!/usr/bin/env python3

import os
import re
from typing import List, Tuple, Dict
import glob

class CodeScanner:
    def __init__(self):
        self.ai_indicators = [
            r"claude",
            r"gpt",
            r"copilot",
            r"TODO:",
            r"FIXME:",
            r"(?i)generated by",
            r"(?i)ai generated",
            r"(?i)openai",
            r"(?i)anthropic",
            r"console\.log\(",  # Likely debugging statements
            r"// Out of context comment",
            r"\/\/ Debug:",
            r"(?i)note to self",
        ]

        self.style_suggestions = {
            r"public\s+(?:uint256|int256|bool|address|string)": 
                "Consider using more specific variable names for public state variables",
            r"require\([^,]+\);": 
                "Consider adding error messages to require statements",
            r"function\s+\w+\s*\([^)]*\)\s*public(?!\s+view|\s+pure)": 
                "Consider if this function should be external instead of public",
            r"[^/]\/.+\/\/": 
                "Multiple comments on same line - consider reformatting",
        }

        self.gas_optimization_patterns = {
            r"storage\s+\w+": 
                "Consider caching storage variables in memory for multiple reads",
            r"uint\s+i\s*=\s*0;\s*i\s*<": 
                "Consider unchecked block for loop counters",
            r"require\((.+?),[^)]+\)": 
                "Consider using custom errors instead of require with messages",
        }

    def scan_file(self, filepath: str) -> Tuple[List[Dict], List[Dict], List[Dict]]:
        with open(filepath, 'r') as file:
            content = file.read()
            line_number = 1
            ai_findings = []
            style_findings = []
            gas_findings = []

            # Process line by line
            for line in content.split('\n'):
                # Check for AI indicators
                for pattern in self.ai_indicators:
                    matches = re.finditer(pattern, line)
                    for match in matches:
                        ai_findings.append({
                            'line': line_number,
                            'pattern': pattern,
                            'match': match.group(),
                            'suggestion': 'Remove or refactor AI-generated indicator'
                        })

                # Check style patterns
                for pattern, suggestion in self.style_suggestions.items():
                    matches = re.finditer(pattern, line)
                    for match in matches:
                        style_findings.append({
                            'line': line_number,
                            'pattern': pattern,
                            'match': match.group(),
                            'suggestion': suggestion
                        })

                # Check gas optimization patterns
                for pattern, suggestion in self.gas_optimization_patterns.items():
                    matches = re.finditer(pattern, line)
                    for match in matches:
                        gas_findings.append({
                            'line': line_number,
                            'pattern': pattern,
                            'match': match.group(),
                            'suggestion': suggestion
                        })

                line_number += 1

            return ai_findings, style_findings, gas_findings

    def generate_report(self, findings: Tuple[List[Dict], List[Dict], List[Dict]], filepath: str):
        ai_findings, style_findings, gas_findings = findings
        
        print(f"\n{'='*80}")
        print(f"Scan Results for {filepath}")
        print(f"{'='*80}\n")

        if ai_findings:
            print("\n🤖 AI Indicators Found:")
            print("-" * 40)
            for finding in ai_findings:
                print(f"Line {finding['line']}: {finding['match']}")
                print(f"Suggestion: {finding['suggestion']}\n")

        if style_findings:
            print("\n🎨 Style Suggestions:")
            print("-" * 40)
            for finding in style_findings:
                print(f"Line {finding['line']}: {finding['match']}")
                print(f"Suggestion: {finding['suggestion']}\n")

        if gas_findings:
            print("\n⛽ Gas Optimization Suggestions:")
            print("-" * 40)
            for finding in gas_findings:
                print(f"Line {finding['line']}: {finding['match']}")
                print(f"Suggestion: {finding['suggestion']}\n")

        if not any([ai_findings, style_findings, gas_findings]):
            print("✅ No issues found!")

def main():
    scanner = CodeScanner()
    
    # Scan all .sol files in src and test directories
    for filepath in glob.glob('src/**/*.sol', recursive=True) + glob.glob('test/**/*.sol', recursive=True):
        findings = scanner.scan_file(filepath)
        scanner.generate_report(findings, filepath)

if __name__ == "__main__":
    main()