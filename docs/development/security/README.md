# Statement on security

At its core, OpenProject is an open-source software that is [developed and published on GitHub](https://github.com/opf/openproject). Every change to the OpenProject code base ends up in an open repository accessible to everyone. This results in a transparent software where every commit can be traced back to the contributor.

Automated tests and manual code reviews ensure that these contributions are safe for the entire community of OpenProject. These tests encompass the correctness of security and access control features. We have ongoing collaborations with security professionals from to test the OpenProject code base for security exploits.

For more information on security and data privacy for OpenProject, please visit: [www.openproject.org/security-and-privacy](https://www.openproject.org/security-and-privacy/).

## Security announcements mailing list

If you want to receive immediate security notifications via email as we publish them, please sign up to our security mailing list: https://www.openproject.org/security-and-privacy/#mailing-list.

No messages except for security advisories or security related announcements will be sent there.

To unsubscribe, you will find a link at the end of every email.

Any security related information will also be published on our [blog](https://www.openproject.org/blog/) and in the [release notes](../../release-notes/).

## Reporting a vulnerability

We take all facets of security seriously at OpenProject. If you want to report a security concerns, have remarks, or contributions regarding security at OpenProject, please reach out to us at [security@openproject.com](mailto:security@openproject.com).

If you can, please send us a PGP-encrypted email using the following key:

- Key ID: [0x7D669C6D47533958](https://pgp.mit.edu/pks/lookup?op=get&search=0x7D669C6D47533958) , 
- Fingerprint BDCF E01E DE84 EA19 9AE1 72CE 7D66 9C6D 4753 3958
- You may also find the key [attached in our OpenProject repository.](https://github.com/opf/openproject/blob/dev/docs/development/security/security-at-openproject.com.asc)

Please include a description on how to reproduce the issue if possible. Our security team will get your email and will attempt to reproduce and fix the issue as soon as possible.

## OpenProject security features

### Authentication and password security

OpenProject administrators can enforce [authentication mechanisms and password rules]() to ensure users choose secure passwords according to current industry standards. Passwords stored by OpenProject are securely stored using salted bcrypt. Alternatively, external authentication providers and protocols (such as LDAP, SAML) can be enforced to avoid using and exposing passwords within OpenProject.

### User management and access control

Administrators are provided with [fine-grained role-based access control mechanisms]() to ensure that users are only seeing and accessing the data they are allowed to on an individual project level.

### Definition of session runtime

Admins can set a specific session duration in the system administration, so that it is guaranteed that a session is automatically terminated after inactivity.

### Two-factor authentication

Secure your authentication mechanisms with a second factor by TOTP standard (or SMS, depending on your instance) to be entered by users upon logging in.

### Security badge

This badge shows the current status of your OpenProject installation. It will inform administrators of an installation on whether new releases or security updates are available for your platform.

### Security alerts

Security updates allow a fast fix of security issues in the system. Relevant channels will be monitored regarding security topics and the responsible contact person will be informed. Software packages for security fixes will be provided promptly. Sign up to our [security mailing list](#security-announcements-mailing-list) to receive all security notifications via e-mail.

### LDAP sync (Enterprise add-on)

Synchronize OpenProject users and groups with your company’s LDAP to update users and group memberships based on LDAP group members.

### Single sign-on

With the single sign-on feature you can securely access OpenProject. Control and secure access to your projects with the main authentication providers.



Find out more about our [GDPR compliance](../../enterprise-guide/enterprise-cloud-guide/gdpr-compliance/).

