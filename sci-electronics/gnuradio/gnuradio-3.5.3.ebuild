# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4
PYTHON_DEPEND="2"

inherit eutils fdo-mime python

DESCRIPTION="Toolkit that provides signal processing blocks to implement software radios"
HOMEPAGE="http://gnuradio.org/"
SRC_URI="http://gnuradio.org/redmine/attachments/download/320/${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="audio doc dot examples fcd grc guile qt4 sdl uhd utils wxwidgets"
REQUIRED_USE="utils? ( wxwidgets )
	fcd? ( audio )"

# bug #348206
# comedi? ( >=sci-electronics/comedilib-0.7 )
RDEPEND="dev-libs/boost
	dev-python/numpy	
	dev-util/cppunit
	sci-libs/fftw:3.0
	sci-libs/gsl
	virtual/cblas
	fcd? ( virtual/libusb:1 )
	audio? (
		media-libs/alsa-lib
		media-sound/jack-audio-connection-kit
		>=media-libs/portaudio-19
	)
	grc? (
		dev-python/cheetah
		dev-python/lxml
		dev-python/pygtk:2
	)
	guile? ( >=dev-scheme/guile-1.8.4 )
	qt4? (
		dev-python/PyQt4[X,opengl]
		dev-python/pyqwt:5
		x11-libs/qt-gui
	)
	sdl? ( media-libs/libsdl )
	uhd? ( dev-libs/uhd )
	wxwidgets? (
		dev-python/wxpython:2.8 
		dev-python/numpy
	)
"
DEPEND="${RDEPEND}
	dev-lang/swig
	dev-util/pkgconfig
	doc? (
		>=app-doc/doxygen-1.5.7.1[dot?]
		app-text/xmlto
	)
	grc? (
		x11-misc/xdg-utils
	)
	dot? (
		media-gfx/graphviz
		media-libs/freetype
	)
"

pkg_setup() {	
	python_set_active_version 2
	python_pkg_setup
}

src_prepare() {
	python_convert_shebangs -q -r 2 "${S}"

	# TODO: find more elegant solution for missing DEPDIR
	mkdir "${S}"/gnuradio-core/src/lib/general/.deps || die
	mkdir "${S}"/gnuradio-core/src/lib/gengen/.deps || die
	mkdir "${S}"/gr-trellis/src/lib/.deps || die
}

src_configure() {
#	local boost_ver=$(best_version ">=dev-libs/boost-1.35")

#	boost_ver=${boost_ver/*boost-/}
#	boost_ver=${boost_ver%.*}
#	boost_ver=${boost_ver/./_}

#	einfo "Using boost version ${boost_ver}"
#		--with-boost=/usr/include/boost-${boost_ver} \
#		--with-boost-libdir=/usr/$(get_libdir)/boost-${boost_ver} \

	econf \
		--enable-all-components \
		--enable-gnuradio-core \
		--enable-gruel \
		--enable-python \
		--disable-gr-comedi \
		--disable-gr-shd \
		--with-lv_arch="generic 64 3dnow abm popcount mmx sse sse2 sse3 ssse3 sse4_a sse4_1 sse4_2 avx" \
		$(use_enable audio gr-audio) \
		$(use_enable doc doxygen) \
		$(use_enable doc docs) \
		$(use_enable dot) \
		$(use_enable examples gnuradio-examples) \
		$(use_enable fcd gr-fcd) \
		$(use_enable grc) \
		$(use_enable guile) \
		$(use_enable uhd gr-uhd) \
		$(use_enable utils gr-utils) \
		$(use_enable wxwidgets gr-wxgui) \
		$(use_enable sdl gr-video-sdl) \
		$(use sdl || echo "--disable-sdltest") \
		$(use_enable qt4 gr-qtgui) \
		$(use_with qt4 qwt-incdir "${EPREFIX}"/usr/include/qwt5)
}

#src_test()
#{
#	emake check || die "emake check failed"
#}

src_install() {
	# Prevent: 
		# *** Post-Install Message ***    
		# Warning: python could not find the gnuradio module.     
		# Make sure that /usr/lib64/python2.6/site-packages is in your PYTHONPATH
#	export PYTHONPATH="${D}/$(python_get_sitedir -b):$PYTHONPATH"

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
#	find "${D}" -name '*.la' -delete
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
