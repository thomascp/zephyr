#!/usr/bin/python
# pylint: disable=C0301,C0103,C0111
from __future__ import print_function
from sys import platform
import os
import sys
import fnmatch
import subprocess
import psutil

import robot

this_path = os.path.abspath(os.path.dirname(__file__))

def install_cli_arguments(parser):
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--robot-framework-remote-server-full-directory", dest="remote_server_full_directory", action="store", help="Full location of robot framework remote server binary.")
    group.add_argument("--robot-framework-remote-server-directory-prefix", dest="remote_server_directory_prefix", action="store", default=os.path.join(this_path, '../output/bin'), help="Directory of robot framework remote server binary. This is concatenated with current configuration to create full path.")
    parser.add_argument("--robot-framework-remote-server-name", dest="remote_server_name", action="store", default="Renode.exe", help="Name of robot framework remote server binary.")
    parser.add_argument("--robot-framework-remote-server-port", dest="remote_server_port", action="store", default=9999, help="Port of robot framework remote server binary.")
    parser.add_argument("--enable-xwt", dest="enable_xwt", action="store_true", default=False, help="Enables support for XWT.")
    parser.add_argument("--exclude", default="", help="Do not run tests marked with a tag.")
    parser.add_argument("--show-log", dest="show_log", action="store_true", default=False, help="Display log messages in console (might corrupt robot summary output).")
    parser.add_argument("--show-monitor", dest="show_monitor", action="store_true", default=False, help="Display monitor window.")
    parser.add_argument("--show-analyzers", dest="show_analyzers", action="store_true", default=False, help="Display analyzers.")
    parser.add_argument("--hot-spot", dest="hotspot", action="store", default=None, help="Test given hot spot action.")

def verify_cli_arguments(options):
    if options.port == str(options.remote_server_port):
        print('Port {} is reserved for Robot Framework remote server and cannot be used for remote debugging.'.format(options.remote_server_port))
        sys.exit(1)

def is_process_running(pid):
    if not psutil.pid_exists(pid):
        return False
    proc = psutil.Process(pid)
    #docs note: is_running() will return True also if the process is a zombie (p.status() == psutil.STATUS_ZOMBIE)
    return proc.is_running() and proc.status() != psutil.STATUS_ZOMBIE

class RobotTestSuite(object):
    instances_count = 0
    robot_frontend_process = None
    hotspot_action = ['None', 'Pause', 'Serialize']
    log_files = []

    def __init__(self, path):
        self.path = path
        self._dependencies_met = set()
        self.remote_server_directory = None

    def prepare(self, options):
        RobotTestSuite.instances_count += 1
        if RobotTestSuite.instances_count > 1:
            return

    def _run_remote_server(self, options):
        if options.remote_server_full_directory is not None:
            self.remote_server_directory = options.remote_server_full_directory
        else:
            self.remote_server_directory = os.path.join(options.remote_server_directory_prefix, options.configuration)

        remote_server_binary = os.path.join(self.remote_server_directory, options.remote_server_name)

        if not os.path.isfile(remote_server_binary):
            print("Robot framework remote server binary not found: '{}'! Did you forget to bootstrap and build?".format(remote_server_binary))
            sys.exit(1)

        args = [remote_server_binary, '--robot-server-port', str(options.remote_server_port)]
        if not options.show_monitor:
            args.append('--hide-monitor')
        if not options.show_log:
            args.append('--hide-log')
        if not options.show_analyzers:
            args.append('--hide-analyzers')
        if not options.enable_xwt and not(options.show_analyzers or options.show_monitor):
           args.append('--disable-xwt')

        if platform.startswith("linux") or platform == "darwin":
            args.insert(0, 'mono')

        if options.port is not None:
            if options.suspend:
                print('Waiting for a debugger at port: {}'.format(options.port))
            args.insert(1, '--debug')
            args.insert(2, '--debugger-agent=transport=dt_socket,server=y,suspend={0},address=127.0.0.1:{1}'.format('y' if options.suspend else 'n', options.port))
        elif options.debug_mode:
            args.insert(1, '--debug')

        if sys.stdin.isatty():
            try:
                for proc in [psutil.Process(pid) for pid in psutil.pids()]:
                    if '--robot-server-port' in proc.cmdline() and str(options.remote_server_port) in proc.cmdline():
                        if not is_process_running(proc.pid):
                            #process is zombie
                            continue
                        print('It seems that Robot process (pid {}, name {}) is currently running on port {}'.format(proc.pid, proc.name(), options.remote_server_port))
                        result = raw_input('Do you want me to kill it? [y/N] ')
                        if result in ['Y', 'y']:
                            proc.kill()
                        break
            except:
                # do nothing here
                pass

        if options.run_gdb:
            args = ['gdb', '-nx', '-ex', 'handle SIGXCPU SIG33 SIG35 SIG36 SIGPWR nostop noprint', '--args'] + args
        RobotTestSuite.robot_frontend_process = subprocess.Popen(args, cwd=self.remote_server_directory, bufsize=1)

    def run(self, options):
        if self.path.endswith('renode-keywords.robot'):
            print('Ignoring helper file: {}'.format(self.path))
            return True
        print('Running ' + self.path)
        result = True

        tests_with_hotspots = []
        tests_without_hotspots = []
        _suite = robot.parsing.model.TestData(source=self.path)
        for test in _suite.testcase_table.tests:
            if any(hasattr(step, 'name') and step.name == 'Hot Spot' for step in test.steps):
                tests_with_hotspots.append(test.name)
            else:
                tests_without_hotspots.append(test.name)

        if RobotTestSuite.robot_frontend_process is None:
            self._run_remote_server(options)
        elif not is_process_running(RobotTestSuite.robot_frontend_process.pid):
            self._run_remote_server(options)

        if any(tests_without_hotspots):
            result = result and self._run_inner(options.fixture, None, tests_without_hotspots, options)
        if any(tests_with_hotspots):
            for hotspot in RobotTestSuite.hotspot_action:
                if options.hotspot and options.hotspot != hotspot:
                    continue
                result = result and self._run_inner(options.fixture, hotspot, tests_with_hotspots, options)

        return result

    def _get_dependencies(self, test_case):
        _suite = robot.parsing.model.TestData(source=self.path)
        test = next(t for t in _suite.testcase_table.tests if hasattr(t, 'name') and t.name == test_case)
        requirements = [s.args[0] for s in test.steps if hasattr(s, 'name') and s.name == 'Requires']
        if len(requirements) == 0:
            return set()
        if len(requirements) > 1:
            raise Exception('Too many requirements for a single test. At most one is allowed.')
        providers = [t for t in _suite.testcase_table.tests if any(hasattr(s, 'name') and s.name == 'Provides' and s.args[0] == requirements[0] for s in t.steps)]
        if len(providers) > 1:
            raise Exception('Too many providers for state {0} found: {1}'.format(requirements[0], ', '.join(providers.name)))
        if len(providers) == 0:
            raise Exception('No provider for state {0} found'.format(requirements[0]))
        res = self._get_dependencies(providers[0].name)
        res.add(providers[0].name)
        return res

    def cleanup(self, options):
        RobotTestSuite.instances_count -= 1
        if RobotTestSuite.instances_count == 0:
            if RobotTestSuite.robot_frontend_process:
                os.kill(RobotTestSuite.robot_frontend_process.pid, 15)
                RobotTestSuite.robot_frontend_process.wait()
            if len(RobotTestSuite.log_files) > 0:
                print("Aggregating all robot results")
                robot.rebot(*RobotTestSuite.log_files, processemptysuite=True, name='Test Suite', outputdir=options.results_directory, output='robot_output.xml')

    @staticmethod
    def _create_suite_name(test_name, hotspot):
        return test_name + (' [HotSpot action: {0}]'.format(hotspot) if hotspot else '')

    def _run_dependencies(self, test_cases_names, options):
        test_cases_names.difference_update(self._dependencies_met)
        if not any(test_cases_names):
            return True
        self._dependencies_met.update(test_cases_names)
        return self._run_inner(None, None, test_cases_names, options)

    def _run_inner(self, fixture, hotspot, test_cases_names, options):
        file_name = os.path.splitext(os.path.basename(self.path))[0]
        suite_name = RobotTestSuite._create_suite_name(file_name, hotspot)

        variables = ['SKIP_RUNNING_SERVER:True', 'DIRECTORY:{}'.format(self.remote_server_directory), 'PORT_NUMBER:{}'.format(options.remote_server_port)]
        if hotspot:
            variables.append('HOTSPOT_ACTION:' + hotspot)
        if options.debug_mode:
            variables.append('CONFIGURATION:Debug')

        test_cases = [(test_name, '{0}.{1}'.format(suite_name, test_name)) for test_name in test_cases_names]
        if fixture:
            test_cases = [x for x in test_cases if fnmatch.fnmatch(x[1], fixture)]
            if len(test_cases) == 0:
                return True
            deps = set()
            for test_name in (t[0] for t in test_cases):
                deps.update(self._get_dependencies(test_name))
            if not self._run_dependencies(deps, options):
                return False

        metadata = 'HotSpot_Action:{0}'.format(hotspot if hotspot else '-')
        log_file = os.path.join(options.results_directory, '{0}{1}.xml'.format(file_name, '_' + hotspot if hotspot else ''))
        RobotTestSuite.log_files.append(log_file)
        return robot.run(self.path, runemptysuite=True, output=log_file, log=None, loglevel='TRACE', report=None, metadata=metadata, name=suite_name, variable=variables, noncritical=['non-critical', 'skipped'], exclude=options.exclude, test=[t[1] for t in test_cases]) == 0
