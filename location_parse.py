import os
from lxml import etree
import csv


if __name__ == '__main__':
    rootdir = '/home/alex/git/IATI-Registry-Refresher/data' # Your IATI XML repository here
    activities_file = '/home/alex/git/IATI-VCE-Chad-Geo/activities_of_interest.csv' # List of IATI identifiers

    with open(activities_file, 'r') as act_file:
        acts = [act.strip() for act in act_file.readlines()]

    header = ["iati_identifier", "lat", "long", "code", "level", "vocabulary", "name"]
    output = list()
    for subdir, dirs, files in os.walk(rootdir):
        for filename in files:
            filepath = os.path.join(subdir, filename)
            print(filename)
            try:
                context = etree.iterparse(filepath, tag='iati-activity', huge_tree=True)
                for _, activity in context:
                    identifiers = activity.xpath("iati-identifier/text()")
                    if identifiers:
                        identifier = identifiers[0].strip()
                        if identifier in acts:

                            locations = activity.xpath("location")
                            for location in locations:

                                admins = location.xpath("administrative")
                                for admin in admins:
                                    admin_row = [
                                        identifier,
                                        "",
                                        "",
                                        admin.attrib.get("code", ""),
                                        admin.attrib.get("level", ""),
                                        admin.attrib.get("vocabulary", ""),
                                        ""
                                    ]
                                    output.append(admin_row)

                                points = location.xpath("point/pos/text()")
                                for point in points:
                                    try:
                                        point_row = [
                                            identifier,
                                            point.replace("\xa0", " ").strip().split(" ")[0],
                                            point.replace("\xa0", " ").strip().split(" ")[1],
                                            "",
                                            "",
                                            "",
                                            ""
                                        ]
                                        output.append(point_row)
                                    except IndexError:
                                        pass

                                if not admins and not points:
                                    location_names = location.xpath("name/narrative/text()")
                                    for location_name in location_names:
                                        name_row = [
                                            identifier,
                                            "",
                                            "",
                                            "",
                                            "",
                                            "",
                                            location_name
                                        ]
                                        output.append(name_row)

                    # Free memory
                    activity.clear()
                    for ancestor in activity.xpath('ancestor-or-self::*'):
                        while ancestor.getprevious() is not None:
                            try:
                                del ancestor.getparent()[0]
                            except TypeError:
                                break

                del context

            except etree.XMLSyntaxError:
                continue

    with open('location_data.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(output)
