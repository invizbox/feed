""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt

    interaction with the uci files """
from glob import glob
from os import sync
from re import sub, compile as re_compile
from utils.validate import validate_option


class UciException(Exception):
    """ Exception wrapper for simplicity """


def uci_characters(raw_string):
    """ simple removal of non uci friendly characters """
    return sub('[^a-zA-Z0-9_]+', '', raw_string)


class Uci:
    """ Handling UCI interactions """

    def __init__(self, config_directory):
        self.config_dir = config_directory
        self.re_comment = re_compile(r'^#(.*)')
        self.re_package = re_compile(r'^package ([^#]*)')
        self.re_config = re_compile(r'^config\s+(\S+)\s*([^#]*)?')
        self.re_option = re_compile(r'^option\s+(\S+)\s+(.*)')
        self.re_list = re_compile(r'^list\s+(\S+)\s+(.*)')
        self.uci_config = {}
        self.parse()

    @staticmethod
    def uci_cleanup(entry):
        """ helper function to cleanup an entry based on the quoting and escaping rules in UCI """
        entry = entry.strip()
        if entry.startswith("'") and entry.endswith("'"):
            entry = entry[1:-1].replace("'\\''", "'")
        elif entry.startswith('"') and entry.endswith('"'):
            entry = entry[1:-1].replace('"\\""', '"')
        return entry

    @staticmethod
    def option_parse(option):  # pylint: disable=too-many-branches
        """ helper function to parse an option value as per UCI (without multiline support)"""
        single_quoted = False
        double_quoted = False
        escaped = False
        final_option = ""
        option = option.strip()
        while option:
            if escaped:
                final_option += option[0]
                option = option[1:]
                escaped = False
            elif option.startswith("'") and not double_quoted:
                if single_quoted:
                    if option.startswith("'\\''"):
                        final_option += "'"
                        option = option[4:]
                    else:
                        single_quoted = False
                        option = option[1:]
                else:
                    single_quoted = True
                    option = option[1:]
            elif option.startswith('"') and not single_quoted:
                if double_quoted:
                    if option.startswith('"\\""'):
                        final_option += '"'
                        option = option[4:]
                    else:
                        double_quoted = False
                        option = option[1:]
                else:
                    double_quoted = True
                    option = option[1:]
            elif option.startswith("\\") and not single_quoted and not double_quoted:
                escaped = True
                option = option[1:]
            elif (option.startswith(" ") or option.startswith("#")) and not single_quoted and not double_quoted:
                break
            else:
                final_option += option[0]
                option = option[1:]
        return final_option

    def parse(self, package="*"):
        """ Parsing UCI config files into a dictionary """
        for config_file_name in glob(self.config_dir + "/" + package):
            package_config = []
            option_config = {}
            with open(config_file_name) as config_file:
                package = config_file_name.split("/")[-1]
                for line in config_file:
                    line = line.strip()
                    pattern = self.re_comment.search(line)
                    if pattern:
                        continue
                    pattern = self.re_package.search(line)
                    if pattern:
                        # no need to parse it as it has to match the filename
                        # package = self.uci_cleanup(pattern.group(1))
                        continue
                    pattern = self.re_config.search(line)
                    if pattern:
                        if option_config:
                            package_config.append(option_config)
                        option_type = self.uci_cleanup(pattern.group(1))
                        option_name = self.uci_cleanup(pattern.group(2))
                        option_config = {".type": option_type, "id": option_name}
                        continue
                    pattern = self.re_option.search(line)
                    if pattern:
                        option_name = self.uci_cleanup(pattern.group(1))
                        option_value = self.option_parse(pattern.group(2))
                        option_config[option_name] = option_value
                        continue
                    pattern = self.re_list.search(line)
                    if pattern:
                        list_name = self.uci_cleanup(pattern.group(1))
                        list_value = self.option_parse(pattern.group(2))
                        if list_name not in option_config.keys():
                            option_config[list_name] = [list_value]
                        else:
                            option_config[list_name].append(list_value)
                        continue
                    if line != "":
                        raise UciException("Unknown Line: " + line)
                # last option in file
                if option_config:
                    package_config.append(option_config)
            self.uci_config[package] = package_config

    @staticmethod
    def build_option_string(config, ):
        """ builds up a string to represent a config in UCI format """
        if config['id']:
            show_string = f"config {config['.type']} '{config['id']}'\n"
        else:
            show_string = f"config {config['.type']}\n"
        for option_name, option_value in sorted(config.items()):
            if option_name not in {".type", "id"}:
                if isinstance(option_value, list):
                    for option_element in option_value:
                        option_element = option_element.replace("'", "'\\''")
                        show_string += f"\tlist {option_name} '{option_element}'\n"
                else:
                    option_value = option_value.replace("'", "'\\''")
                    show_string += f"\toption {option_name} '{option_value}'\n"
        return show_string

    def show_package(self, package, print_it=False):
        """ shows a package configuration in a file compatible structure """
        show_string = f"package {package}\n"
        try:
            for config in self.uci_config[package]:
                show_string += "\n" + self.build_option_string(config)
            if print_it:
                print(show_string)
            return show_string
        except KeyError:
            raise UciException("Invalid Package")

    def show_config(self, package, config, print_it=False):
        """ shows a config configuration item by ID in a file compatible structure """
        current_package = self.uci_config[package]
        config = next(opt for opt in current_package if opt["id"] == config)
        show_string = self.build_option_string(config)
        if print_it:
            print(show_string)
        return show_string

    def get_package(self, package):
        """ get full package"""
        try:
            current_package = self.uci_config[package]
            return current_package
        except KeyError:
            raise UciException("Invalid package")

    def get_config(self, package, config):
        """ get full config """
        try:
            current_package = self.uci_config[package]
            current_config = next(opt for opt in current_package if opt["id"] == config)
            return current_config
        except KeyError:
            raise UciException("Invalid package")
        except StopIteration:
            raise UciException("Invalid config")

    def add_config(self, package, config):
        """ add a new config """
        try:
            current_package = self.uci_config[package]
            current_package.append(config)
        except KeyError:
            raise UciException("Invalid package")

    def delete_config(self, package, config):
        """ remove a config by id """
        try:
            current_package = self.uci_config[package]
            self.uci_config[package] = [opt for opt in current_package if opt["id"] != config]
        except KeyError:
            raise UciException("Invalid package")

    def get_option(self, package, config, option):
        """ get value in memory """
        try:
            current_package = self.uci_config[package]
            current_config = next(opt for opt in current_package if opt["id"] == config)
        except KeyError:
            raise UciException("Invalid package")
        except StopIteration:
            raise UciException("Invalid config")
        try:
            return current_config[option]
        except KeyError:
            raise UciException("Invalid option")

    def set_option(self, package, config, option, value):
        """ change a value in memory """
        if not validate_option("string", option):
            raise UciException("Invalid option")
        if not validate_option("string", value) and not validate_option("string_list", value):
            raise UciException("Invalid value")
        try:
            current_package = self.uci_config[package]
            current_config = next(opt for opt in current_package if opt["id"] == config)
        except KeyError:
            raise UciException("Invalid package")
        except StopIteration:
            raise UciException("Invalid config")
        current_config[option] = value

    def delete_option(self, package, config, option):
        """ remove an option """
        try:
            current_package = self.uci_config[package]
            current_config = next(opt for opt in current_package if opt["id"] == config)
        except KeyError:
            raise UciException("Invalid package")
        except StopIteration:
            raise UciException("Invalid config")
        try:
            del current_config[option]
        except KeyError:
            raise UciException("Invalid option")

    def persist(self, package):
        """ Persists to disc the current representation of a UCI package """
        try:
            new_content = self.show_package(package)
            with open(f"{self.config_dir}/{package}", 'w') as config_handle:
                config_handle.write(new_content)
            sync()
        except UciException as exception:
            raise exception
