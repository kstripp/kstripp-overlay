# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="3"

# TODO: check if GNURadio works with Python3
PYTHON_DEPEND="2:2.5"

inherit flag-o-matic eutils python fdo-mime

DESCRIPTION="GNU Radio"
LICENSE="GPL-2"
HOMEPAGE="http://gnuradio.org/redmine/projects/gnuradio/wiki"
SRC_URI="ftp://ftp.gnu.org/gnu/gnuradio/${P}.tar.gz"
SLOT="0"
IUSE="alsa comedi doc dot examples grc jack oss portaudio sdl usrp usrp2 wxwidgets qt4"
KEYWORDS="x86 amd64"

DEPEND=">=dev-lang/python-2.5
	>=dev-lang/swig-1.3.31
	>=dev-util/pkgconfig-0.18
	>=sci-libs/fftw-3.0
	>=dev-util/cppunit-1.9.14
	>=dev-libs/boost-1.35
	>=sci-libs/gsl-1.10
	>=dev-scheme/guile-1.8.4
	>=dev-python/numpy-1.3.0
	alsa? ( media-libs/alsa-lib
   	        media-sound/alsa-headers )
	comedi? ( >=sci-electronics/comedilib-0.7 )
	doc? ( 	dot? ( >=app-doc/doxygen-1.5.7.1[-nodot] )
			>=app-doc/doxygen-1.5.7.1
			>=app-text/xmlto-0.0.22 )
	grc? ( 	>=dev-python/cheetah-2.0
			>=dev-python/lxml-2.0
			>=dev-python/pygtk-2.10
			x11-misc/xdg-utils )
	jack? ( media-sound/jack-audio-connection-kit )
	portaudio? ( >=media-libs/portaudio-19 )
	qt4? ( 	dev-python/PyQt4[opengl,X]
			x11-libs/qt-qt3support
			x11-libs/qwt:5
			>=x11-libs/qwtplot3d-0.2.6-r2 )
	sdl? ( media-libs/libsdl )
	usrp? (	>=dev-embedded/sdcc-2.8.0
			virtual/libusb )
	wxwidgets? ( dev-python/wxpython:2.8 
			dev-python/numpy )"

pkg_setup() {
	if ! use wxwidgets && use grc ; then
		die "wxwidgets need to be enabled in order to build grc."
	fi

	python_set_active_version 2
}

src_prepare() {
	python_convert_shebangs -q -r 2 .
}

src_configure() {
	local boost_ver=$(best_version ">=dev-libs/boost-1.35")

	boost_ver=${boost_ver/*boost-/}
	boost_ver=${boost_ver%.*}
	boost_ver=${boost_ver/./_}

	einfo "Using boost version ${boost_ver}"

	# PS3 cell support is disabled, change the ebuild if you want it
	# usrp2 firmware requires a gcc toolchain for the MicroBlaze arch
	econf \
		--enable-all-components \
		--with-boost=/usr/include/boost-${boost_ver} \
		--with-boost-libdir=/usr/$(get_libdir)/boost-${boost_ver} \
		--enable-gnuradio-core \
		--enable-gruel \
		--disable-gr-audio-windows \
		--disable-gr-audio-osx \
		--disable-gcell \
		--disable-gr-gcell \
		--disable-usrp2-firmware \
		$(use_enable alsa gr-audio-alsa) \
		$(use_enable doc doxygen) \
		$(use_enable doc docs) \
		$(use_enable dot) \
		$(use_enable comedi gr-comedi) \
		$(use_enable examples gnuradio-examples) \
		$(use_enable grc) \
		$(use_enable usrp) \
		$(use_enable usrp gr-usrp) \
		$(use_enable usrp gr-gpio) \
		$(use_enable usrp gr-radar-mono) \
		$(use_enable usrp gr-sounder) \
		$(use usrp && use wxwidgets && echo "--enable-gr-utils" || echo "--disable-gr-utils") \
		$(use_enable usrp2) \
		$(use_enable usrp2 gr-usrp2) \
		$(use_enable jack gr-audio-jack) \
		$(use_enable oss gr-audio-oss) \
		$(use_enable portaudio gr-audio-portaudio) \
		$(use_enable wxwidgets gr-wxgui) \
		$(use_enable sdl gr-video-sdl) \
		$(use sdl || echo "--disable-sdltest") \
		$(use_enable qt4 gr-qtgui) \
		$(use_with qt4 qwt-incdir /usr/include/qwt5) \
		|| die "econf failed"
}

src_test()
{
	emake check || die "emake check failed"
}

src_install() {
	# Prevent: 
		# *** Post-Install Message ***    
		# Warning: python could not find the gnuradio module.     
		# Make sure that /usr/lib64/python2.6/site-packages is in your PYTHONPATH
	export PYTHONPATH="${D}/$(python_get_sitedir -b):$PYTHONPATH"

	# linking failure without -j1
	emake -j1 DESTDIR="${D}" install || die "emake install failed"

	python_clean_installation_image -q

	# Install examples to /usr/share/doc/$PF
	if use examples ; then
		mkdir -p "${D}/usr/share/doc/${PF}/" &&
		mv "${D}/usr/share/gnuradio/examples/"* "${D}/usr/share/doc/${PF}/" || die "failed installing examples"
	fi
	# It seems that the examples are installed whether configured or not
	rm -rf "${D}/usr/share/gnuradio/examples"

	# Remove useless files in the doc dir
	find "${D}/usr/share/doc/${PF}/html" -name '*.md5' -delete
	rm -rf "${D}/usr/share/doc/${PF}/xml"

	# We install the mimetypes to the correct locations from the ebuild
	rm -rf "${D}/usr/share/gnuradio/grc/freedesktop"
	rm -f "${D}/usr/bin/grc_setup_freedesktop"

	# Install icons, menu items and mime-types for GRC
	if use grc ; then
		local fd_path="${S}/grc/freedesktop"
		insinto /usr/share/mime/packages
		doins "${fd_path}/gnuradio-grc.xml" || die "failure installing mime-types"

		domenu "${fd_path}/"*.desktop || die ".desktop file install failed"
		doicon "${fd_path}/"*.png || die "icon install failed"
	fi

	# Remove useless .la files
	find "${D}" -name '*.la' -delete
}

GRC_ICON_SIZES="32 48 64 128 256"
pkg_postinst()
{
	python_mod_optimize gnuradio

	if use grc ; then
		fdo-mime_desktop_database_update
		fdo-mime_mime_database_update
		for size in ${GRC_ICON_SIZES} ; do
			xdg-icon-resource install --noupdate --context mimetypes --size ${size} \
				"${ROOT}/usr/share/pixmaps/grc-icon-${size}.png" application-gnuradio-grc \
				|| die "icon resource installation failed"
			xdg-icon-resource install --noupdate --context apps --size ${size} \
				"${ROOT}/usr/share/pixmaps/grc-icon-${size}.png" gnuradio-grc \
				|| die "icon resource installation failed"
		done
		xdg-icon-resource forceupdate
	fi
}

pkg_postrm()
{
	python_mod_cleanup gnuradio

	if use grc ; then
		fdo-mime_desktop_database_update
		fdo-mime_mime_database_update
		for size in ${GRC_ICON_SIZES} ; do
			xdg-icon-resource uninstall --noupdate --context mimetypes --size ${size} \
				application-gnuradio-grc || ewarn "icon uninstall failed"
			xdg-icon-resource uninstall --noupdate --context apps --size ${size} \
				gnuradio-grc || ewarn "icon uninstall failed"

		done
		xdg-icon-resource forceupdate
	fi
}
