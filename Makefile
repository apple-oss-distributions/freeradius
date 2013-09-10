##
# Makefile for freeradius
##

# Project info
Project                = freeradius
ProjectName            = freeradius
ProjectDir             = $(shell pwd)
UserType               = Administrator
ToolType               = Commands

# Get server paths
include /AppleInternal/ServerTools/ServerBuildVariables.xcconfig

Extra_CC_Flags         = -fno-common -gdwarf-2
Extra_CC_Flags        += -F /System/Library/PrivateFrameworks -I ${OBJROOT}/src

Extra_LD_Flags         = -F /System/Library/PrivateFrameworks
Extra_LD_Libraries     = /System/Library/PrivateFrameworks/nt.framework/nt -framework CoreFoundation -framework OpenDirectory -L${SERVER_INSTALL_PATH_PREFIX}/usr/lib/freeradius

Extra_Configure_Flags  = --disable-static --enable-shared
Extra_Configure_Flags += --srcdir=.
Extra_Configure_Flags += --prefix=$(SERVER_INSTALL_PATH_PREFIX)/usr
Extra_Configure_Flags += --sysconfdir=$(SERVER_LIBRARY_PATH)/radius
Extra_Configure_Flags += --libdir=$(SERVER_INSTALL_PATH_PREFIX)/usr/lib/freeradius
Extra_Configure_Flags += --includedir=/usr/local/include
Extra_Configure_Flags += --localstatedir=/private/var
Extra_Configure_Flags += --enable-ltdl-install=yes  --without-rlm_perl --without-rlm_sql_mysql

Extra_Install_Flags   = prefix=$(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr
Extra_Install_Flags  += sysconfdir=$(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/$(SERVER_LIBRARY_PATH)/radius
Extra_Install_Flags  += libdir=$(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/lib/freeradius
Extra_Install_Flags  += mandir=$(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/share/man
Extra_Install_Flags  += localstatedir=$(DSTROOT)/private/var
Extra_Install_Flags  += includedir=$(DSTROOT)/usr/local/include

GnuNoBuild      = YES
GnuAfterInstall = install-plists remove-dirs copy-to-symroot-and-strip fix-man-pages

# These variables find all the freeradius executable & library files
# in $(DSTROOT).  They are used for generating dsyms & symbol stripping.
fr_file_finder = $(notdir $(shell /usr/bin/file -h $(addsuffix /*,$(1)) | /usr/bin/grep 'Mach-O' | /usr/bin/sed -e s/:.*//))
fr_bin_files  = $(call fr_file_finder,$(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/bin)
fr_sbin_files = $(call fr_file_finder,$(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/sbin)
fr_lib_files  = $(call fr_file_finder,$(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/lib/freeradius)

lazy_install_source:: full_copy_source

include $(MAKEFILEPATH)/CoreOS/ReleaseControl/GNUSource.make

Install_Target = install

STD_CCFLAGS = $(CC_Debug) $(CC_Other) $(CC_Archs)

# Some of the freeradius makefiles use the 'test -f somefile' which fails
# if the file is a symlink (as it would be for shadow_source).  And since
# the configure scripts depend on the source being in the build directory,
# a full copy of the source is needed in $(OBJROOT).

full_copy_source:
	echo "Creating full copy of sources in the build directory...";
	cd $(Sources) && $(PAX) -rw . $(OBJROOT)


# Override the normal build target because $Environment uses "CFLAGS=..."
# which wipes out all of the "CFLAG+=" statements used in the freeradius
# makefiles.

build::
	umask $(Install_Mask) && cd $(BuildDirectory) && LDFLAGS+="$(Extra_LD_Flags) $(Extra_LD_Libraries)" CFLAGS+="$(Extra_CC_Flags) $(STD_CCFLAGS)" $(MAKE)

install-plists:
	$(MKDIR) -p $(DSTROOT)/usr/local/OpenSourceLicenses
	$(INSTALL) -m 644 $(SRCROOT)/freeradius/LICENSE $(DSTROOT)/usr/local/OpenSourceLicenses/freeradius.txt
	$(MKDIR) -p $(DSTROOT)/usr/local/OpenSourceVersions
	$(INSTALL) -m 644 $(SRCROOT)/freeradius.plist $(DSTROOT)/usr/local/OpenSourceVersions/freeradius.plist
	$(MKDIR) -p $(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/System/Library/LaunchDaemons
	$(INSTALL) -m 644 $(SRCROOT)/org.freeradius.radiusd.plist $(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/System/Library/LaunchDaemons/

remove-dirs:
	$(RMDIR) $(DSTROOT)/private/var/run


# Copying the files to $(SYMROOT) magically triggers dsym generation.
# Go to the individual directories so the relative file name can be
# used in the commands.  This avoids really long command lines, which
# run the risk of exceeding the max length.
copy-to-symroot-and-strip:
	cd $(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/bin && $(CP) $(fr_bin_files) $(SYMROOT) && $(STRIP) $(fr_bin_files)
	cd $(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/sbin && $(CP) $(fr_sbin_files) $(SYMROOT) && $(STRIP) -u -r $(fr_sbin_files)
	cd $(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/lib/freeradius && $(CP) $(fr_lib_files) $(SYMROOT) && $(STRIP) -x $(fr_lib_files)

fix-man-pages:
	cd $(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/share/man/man8 && ln -fs radiusd.8 checkrad.8
	cd $(DSTROOT)/$(SERVER_INSTALL_PATH_PREFIX)/usr/share/man/man8 && ln -fs radiusd.8 rc.radiusd.8
