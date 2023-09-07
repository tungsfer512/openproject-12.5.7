---
sidebar_navigation:
  title: Time and costs FAQ
  priority: 001
description: Frequently asked questions regarding time, costs and tracking
keywords: time and costs FAQ, time tracking, time logging, booking costs
---

# Frequently asked questions (FAQ) for Time and costs

## Is there a way to prevent logging hours for Phases (or other work package types)? 

It is not possible to prevent time logging on phases or restrict it to certain work package types. You could deactivate the fields "Estimated time" and "Spent time" for type Phase (using the [work package form configuration](../../../system-admin-guide/manage-work-packages/work-package-types/#work-package-form-configuration-enterprise-add-on)) but it would still be possible to log time for Phases.

## Can I log time for another user than myself?

Currently, that's not possible. However, there's already a [feature request](https://community.openproject.com/projects/openproject/work_packages/21754/activity) on our wish list.

Possible workarounds: 

- Log in as the other user.
- Set up a cost type (e.g."developer hours" or "John Smith") for unit costs and use this to log time (as unit cost) for others.
- Add a comment with the user's name in the time logging modal. If you want to see the comment in the time and costs module you will have to remove all selections for columns and rows.
- Use the "Activity" drop down menu to choose a user (you can add their names [in the system administration](../../../system-admin-guide/enumerations/)). Then you could use the time and costs module to filter for or sort by "Activity". 
- Create a work package as a dummy. It should have a special status so that it can be reliably excluded in time reporting. For this work package, each user for whom times are to be booked by others (e.g. project managers) creates several entries (time bookings) with sample values in advance. Subsequently, the project manager can assign these time entries to another work package if required and enter the actual effort.

## Is it possible to view all hours assigned to each member in total? If I work on various projects I'd like to know how many hours I accumulated for all tasks assigned to me.

Yes, it is possible to see all hours assigned to each user in total. In your cost report you would just need to [select](../reporting/#filter-cost-reports) all projects that you would want to look at.
Click on the **+** next to the project filter, select all projects or the ones that you would like to select (use Ctrl or Shift key), choose all other filters and then click **Apply** to generate the cost report.

## Can I show the columns I chose in the Time and costs module in the Excel export?

Unfortunately this is not possible at the moment. There's already a feature request for this on our wish list [here](https://community.openproject.org/work_packages/35042).

## Is there an overview over how much time I logged in one week?

Yes, you can use the "My spent time" widget on My Page and use the filters there.

## Does OpenProject offer resource management?

You can [set up budgets](../../budgets), [set an Estimated time](../../work-packages/edit-work-package/) for a work package and use the [Assignee board](../../agile-boards/#choose-between-board-types) to find out how many work packages are assigned to a person at the moment.
Additional resource management features will be added within the next years. You can find the road-map for future releases [here](https://community.openproject.com/projects/openproject/work_packages?query_id=1993).
More infomation regarding resource management in OpenProject can be found in the [Use Cases](../../../use-cases/resource-management) section.
