import requests
import json
import sys
import time
import argparse
from requests.packages.urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

API_KEY = ''
SCANNER_URL = 'https://127.0.0.1:3443'
PROFILE_ID = '11111111-1111-1111-1111-111111111111'  # you can change to custom if you want, else 'Full Scan'
UPLOAD_URL = ''
output_file = ''


class AcunetixManager(object):
    API_KEY = ''
    SCANNER_URL = ''
    N = 499  # acunetix doesn't allow to add more for one time now
    full_scan_profile_id = '11111111-1111-1111-1111-111111111111'
    headers = {}
    sended_targets_counter = 0
    decreased_speed_targets_counter = 0
    number_targets = 0

    def __init__(self, API_KEY, SCANNER_URL):
        self.API_KEY = API_KEY
        self.SCANNER_URL = SCANNER_URL
        self.output_file = output_file
        self.headers = {
            'identity': 'REDnetix',
            'Content-type': 'application/json',
            'Accept': 'text/plain',
            'X-Auth': API_KEY
        }
        self.headers_import_url = {
            'identity': 'REDnetix',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Auth': API_KEY,
        }

    def remove_all_targets(self):
        counter_removed_targets = 0
        current_avaliable_targets = -1
        while current_avaliable_targets != 0:
            response = requests.get(
                '%s/api/v1/targets?l=100' % self.SCANNER_URL,
                headers=self.headers,
                verify=False)
            if response.status_code == 200:
                current_avaliable_targets = len(json.loads(response.text)['targets'])
            else:
                print(response.text)
                print('Something wrong. fail getting targets')
                exit()
            target_id_list = [target['target_id'] for target in json.loads(response.text)['targets']]
            # print(target_id_list)
            response = requests.post(
                '%s/api/v1/targets/delete' % self.SCANNER_URL,
                headers=self.headers,
                verify=False,
                data=json.dumps({"target_id_list": target_id_list}))
            if response.status_code == 204:
                counter_removed_targets += 100
                print("success removed", counter_removed_targets)
            else:
                print('Something wrong. fail removing targets')
                print(response.text)
                exit()

    def get_url(self, list_target_id, crawler_urls):
        for target_id in list_target_id:
            urlss = SCANNER_URL + '/api/v1/targets/' + target_id + '/configuration/imports'
            data = {"name": "URLs.txt", "size": 30}
            response = requests.post(urlss, headers=self.headers_import_url, verify=False, json=data)
            # print(response)

            if response.status_code == 200:
                data = response.json()
                UPLOAD_URL = data['upload_url']
            # print(UPLOAD_URL)
            else:
                print('Error when trying to get URL')

            # upload URLs.txt
            full_url = SCANNER_URL + UPLOAD_URL
            data = open(crawler_urls, 'rb').read()
            print(data)
            headers_upload_crawler = {
                'Host': '127.0.0.1:3443',
                # 'Connection': 'close',
                # 'Content-Length': '30',
                'Content-Range': 'bytes 0-29/30',
                'Accept': 'application/json, text/plain, */*',
                'Cache-Control': 'no-cache',
                'x-auth': API_KEY,
                'Content-Disposition': 'attachment; filename="URLs.txt"',
                # 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36',
                'Content-Type': 'application/octet-stream',
                'Origin': 'https://127.0.0.1:3443',
                'Sec-Fetch-Site': 'same-origin',
                'Sec-Fetch-Mode': 'cors',
                'Sec-Fetch-Dest': 'empty',
                'Referer': 'https://127.0.0.1:3443/',
                # 'Accept-Encoding': 'gzip, deflate',
                'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
                'identity': 'REDnetix',

            }

            response = requests.post(full_url, headers=headers_upload_crawler, data=data, verify=False)
            print(response.status_code)

    def add_targets_to_scanner(self, targets, group_id=None):
        if group_id is None:
            response = requests.post(
                '%s/api/v1/targets/add' % self.SCANNER_URL,
                headers=self.headers,
                verify=False,
                data=json.dumps(
                    {'targets': [{"address": host, "description": "", "criticality": 30} for host in targets],
                     "groups": []}))
        else:
            response = requests.post(
                '%s/api/v1/targets/add' % self.SCANNER_URL,
                headers=self.headers,
                verify=False,
                data=json.dumps(
                    {'targets': [{"address": host, "description": "", "criticality": 30} for host in targets],
                     "groups": [group_id]}))

        if response.status_code == 200:
            print("Success adding targets")

            target_iq = [target['target_id'] for target in json.loads(response.text)['targets']]
            print(target_iq)
        else:
            print(response.text)
            print('Something wrong. fail adding')
            exit()
        list_target_id = [target_info['target_id'] for target_info in json.loads(response.text)['targets']]
        return list_target_id

    def run_scanner(self, report_filename, targets_filename, crawler_urls, profile_id=full_scan_profile_id, group_name=None,
                    scan_speed=None):  # by default 'Full Scan'
        self.output_file = report_filename
        if group_name is not None:
            group_id = self.create_group(group_name)
        else:
            group_id = None

        # with open(targets_filename) as file:
        # 	hosts = [line.rstrip('\n') for line in file]
        hosts = []
        hosts.append(targets_filename)
        self.number_targets = len(hosts)
        for chunk in self.chunks(hosts, self.N):
            list_target_id = self.add_targets_to_scanner(chunk, group_id=group_id)
            if scan_speed != None:
                self.change_scan_speed(list_target_id, scan_speed)

            self.get_url(list_target_id, crawler_urls)
            # exit()
            self.send_to_scan(list_target_id, profile_id)
            self.get_status(list_target_id)
            ###################
            try:
                detailed_results = []
                scan_id = self.from_target_id_to_scan_id(list_target_id)
                result = self.get_scan_results(scan_id)
                r = result["results"]
                r = str(r)
                start_index = r.find("'result_id': '") + len("'result_id': '")
                end_index = r.find("'", start_index)
                desired_value = r[start_index:end_index]
                done = self.get_list_vuln(scan_id, desired_value)

                r = str(done)
                start_index = r.find("'vt_name': '") + len("'vt_name': '")
                end_index = r.find("'", start_index)
                desired_value2 = r[start_index:end_index]
                if desired_value2 != 'lities':
                    start_index = r.find("'affects_url': '") + len("'affects_url': '")
                    end_index = r.find("'", start_index)
                    desired_value2 += " - "
                    desired_value2 += r[start_index:end_index]
                    detailed_results.append(desired_value2)
                self.write_results_to_file(detailed_results)
                print(f'Results are saved in a file: {self.output_file}')
            except requests.exceptions.RequestException as e:
                print(f'Error while executing request: {e}')
            except json.JSONDecodeError as e:
                print(f'Error processing JSON data: {e}')
            except Exception as e:
                print(f'An error has occurred: {e}')
        ###################

    # self.sended_targets_counter = 0
    # self.decreased_speed_targets_counter = 0

    def change_scan_speed(self, list_target_id, speed_mode):
        for target_id in list_target_id:
            self.decreased_speed_targets_counter += 1
            response = requests.patch(
                '%s/api/v1/targets/%s/configuration' % (self.SCANNER_URL, target_id),
                headers=self.headers,
                verify=False,
                timeout=None,
                data=json.dumps(
                    {"scan_speed": speed_mode, "login": {"kind": "none"}, "ssh_credentials": {"kind": "none"},
                     "sensor": False,
                     "user_agent": "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.21 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.21",
                     "case_sensitive": "auto", "limit_crawler_scope": False, "excluded_paths": [],
                     "authentication": {"enabled": False}, "proxy": {"enabled": False}, "technologies": [],
                     "custom_headers": [], "custom_cookies": [], "debug": False, "client_certificate_password": "",
                     "client_certificate_url": None, "issue_tracker_id": "", "excluded_hours_id": ""})
            )
            time.sleep(3)
            if response.status_code == 204:
                print("Success configurated %d/%d" % (self.decreased_speed_targets_counter, self.number_targets))
            else:
                print(response.text)
                print(target_id, "fail config")
                exit()

    def send_to_scan(self, list_target_id, profile_id):
        for target_id in list_target_id:
            self.sended_targets_counter += 1
            response = requests.post(
                '%s/api/v1/scans' % self.SCANNER_URL,
                headers=self.headers,
                verify=False,
                timeout=None,
                data=json.dumps({"profile_id": profile_id, "incremental": False,
                                 "schedule": {"disable": False, "start_date": None, "time_sensitive": False},
                                 "target_id": target_id}))
            time.sleep(3)
            if response.status_code == 201:
                # print(response.text)
                print("Success send to scan %d/%d" % (self.sended_targets_counter, self.number_targets))
            else:
                print(response.text)
                print('Something wrong. fail send to scan')
                exit()

    def get_status(self, list_target_id):
        status = "processing"
        while status == "processing":
            time.sleep(100)
            # print(".", end="")
            response = requests.get(
                'https://127.0.0.1:3443/api/v1/targets/' + ''.join(list_target_id),
                headers=self.headers,
                verify=False,
                timeout=None)
            time.sleep(5)
            if response.status_code == 200:
                status = json.loads(response.text)['last_scan_session_status']
                print("Status: " + status)

            else:
                print(response.text)
                print('Something wrong. fail to get status')
                exit()
        else:
            print("Scan finished")

    #########################
    def from_target_id_to_scan_id(self, target_id):
        params = {
            "target_id": target_id,
            "last": 1
        }
        headers = {'X-Auth': API_KEY}
        url = f'{SCANNER_URL}/api/v1/scans'
        response = requests.get(url, headers=headers, params=params, verify=False)
        scan_id = ''
        if response.status_code == 200:
            data = response.json()
            if data["scans"]:
                scan_id = data["scans"][0]["scan_id"]
                print(f"Scan ID of the last scan for target {target_id}: {scan_id}")
            else:
                print(f"No scans found for target {target_id}")
        else:
            print(f"Request failed with status code: {response.status_code}")
        return scan_id

    def get_scan_results(self, scan_id):
        headers = {'X-Auth': API_KEY}
        url = f'{SCANNER_URL}/api/v1/scans/{scan_id}/results'
        response = requests.get(url, headers=headers, verify=False)
        response.raise_for_status()
        return response.json()

    def get_list_vuln(self, scan_id, result_id):
        headers = {'X-Auth': API_KEY}
        url = f'{SCANNER_URL}/api/v1/scans/{scan_id}/results/{result_id}/vulnerabilities'
        response = requests.get(url, headers=headers, verify=False)
        response.raise_for_status()
        return response.json()

    def write_results_to_file(self, results):
        with open(self.output_file, 'w', encoding='utf-8') as f:
            for i in results:
                f.write(i + '\n')

    #########################
    def chunks(self, lst, n):
        return [lst[i:i + n] for i in range(0, len(lst), n)]

    def get_group_id(self, group_name):
        response = requests.get(
            '%s/api/v1/target_groups?l=100' % self.SCANNER_URL,
            headers=self.headers,
            verify=False)
        time.sleep(3)
        if response.status_code == 200:
            for group in json.loads(response.text)['groups']:
                if group_name == group['name']:
                    return group['group_id']

    def create_group(self, group_name):
        response = requests.post(
            '%s/api/v1/target_groups' % self.SCANNER_URL,
            headers=self.headers,
            verify=False,
            data=json.dumps({"name": group_name, "description": ""}))
        time.sleep(3)
        if response.status_code == 201:
            print(group_name + ' group successfuly created')
            group_id = json.loads(response.text)['group_id']
        elif response.status_code == 409 and json.loads(response.text)['message'] == "Group name should be unique":
            print(group_name + ' already exists')
            return self.get_group_id(group_name)
        else:
            print(response.text)
            print('Something wrong. fail creating group')
            exit()
        return group_id


def main():
    if sys.version_info[0] < 3:
        raise Exception("Python 3 or a more recent version is required.")
    parser = argparse.ArgumentParser(description='Acunetix helpful script')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-rmrf",
                       help="removing all targets",
                       action='store_true')
    group.add_argument("-f", "--file",
                       dest="filename",
                       help="file which contains list of urls/domans",
                       metavar="FILE",
                       )
    parser.add_argument("-u", "--urls",
                        dest="crawler_urls",
                        default=None,
                        help="upload txt file for crawler")
    parser.add_argument("-r", "--report",
                        dest="report_filename",
                        help="save report",)

    parser.add_argument("-g", "--group",
                        dest="group_name",
                        default=None,
                        help="if group doesn't exist it will be created. All hosts will be added to this group")
    parser.add_argument("-d", "--decrease",
                        dest="speed_decrease",
                        help="decrease scan speed",
                        default=None,
                        choices=['moderate', 'slow', 'sequential'])

    args = parser.parse_args()

    acu = AcunetixManager(API_KEY, SCANNER_URL)
    if args.rmrf:
        acu.remove_all_targets()
    elif args.filename:
        acu.run_scanner(args.report_filename, args.filename, args.crawler_urls, profile_id=PROFILE_ID, group_name=args.group_name,
                        scan_speed=args.speed_decrease)


if __name__ == "__main__":
    main()
