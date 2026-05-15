import os
import re

# We want to remove lines that consist entirely of a comment, which look like structural annotations
# such as "// Avatar" or "// Search Bar" or "// Find which block has focus"
# Pattern: optional whitespace, then //, optional whitespace, then a capital letter, 
# then some characters (letters, numbers, spaces, basic punctuation) without semicolons or brackets
# which indicates it's an english sentence/phrase and not commented out code.
PATTERN = re.compile(r'^\s*//\s*[A-Z][A-Za-z0-9\s,\.\-\+\&\'\"]*$')

# Also delete these specifically verbose ones
SPECIFIC_PATTERNS = [
    re.compile(r'^\s*//\s*The server responded with a status code that falls out of the range of 2xx\s*$'),
    re.compile(r'^\s*//\s*Something happened in setting up or sending the request that triggered an Error\s*$'),
    re.compile(r'^\s*//\s*Provide the Isar instance synchronously once initialized\s*$'),
]

def clean_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    deleted_count = 0
    for line in lines:
        keep = True
        
        if PATTERN.match(line) and len(line.strip()) < 80:
            keep = False
            
        for sp in SPECIFIC_PATTERNS:
            if sp.match(line):
                keep = False
                
        if keep:
            new_lines.append(line)
        else:
            deleted_count += 1
            
    if deleted_count > 0:
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f"Cleaned {deleted_count} comments from {path}")

def main():
    lib_dir = '/Users/abhis/Desktop/cortex/lib'
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                clean_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
