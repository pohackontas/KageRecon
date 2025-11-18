import argparse
import difPy

def my_parse_args():
    parser = argparse.ArgumentParser()  # Initialize parser https://www.geeksforgeeks.org/command-line-arguments-in-python/
    parser.add_argument("-p", "--path")
    parser.add_argument("-d", "--double_path", nargs=2)
    args = parser.parse_args()  # Read arguments from command line
    return args

if __name__ == '__main__':
    args = my_parse_args()
    if args.path:
        dif1 = difPy.build(args.path)
        search1 = difPy.search(dif1, similarity="similar")
        search1.delete(silent_del=True)
    if args.double_path:
        dif2 = difPy.build(args.double_path[0], args.double_path[1])
        search2 = difPy.search(dif2, similarity="similar")
        search2.delete(silent_del=True)