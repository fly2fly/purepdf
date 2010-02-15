package test_reader
{
	import com.adobe.images.PNGEncoder;
	
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	
	import org.purepdf.pdf.PRStream;
	import org.purepdf.pdf.PdfName;
	import org.purepdf.pdf.PdfObject;
	import org.purepdf.pdf.PdfReader;
	import org.purepdf.pdf.PdfStream;
	import org.purepdf.utils.Bytes;

	public class ExtractImages extends SimpleReader
	{
		public function ExtractImages()
		{
			super( "../output/ImageTypes.pdf" );
		}

		override protected function onComplete( event: Event ): void
		{
			super.onComplete( event );

			var reader: PdfReader = new PdfReader( pdf );
			reader.readPdf();

			var obj: PdfObject;
			var stream: PdfStream;
			var subtype: PdfObject;
			for ( var k: int = 0; k < reader.getXrefSize(); ++k )
			{
				obj = reader.getPdfObject( k );
				if ( obj && obj.isStream() )
				{
					stream = PdfStream( obj );
					subtype = stream.getValue( PdfName.SUBTYPE );
					if ( subtype && subtype.equals( PdfName.IMAGE ) )
					{
						trace( "height:" + stream.getValue( PdfName.HEIGHT ) );
						trace( "width:" + stream.getValue( PdfName.WIDTH ) );
						trace( "bitspercomponent:" + stream.getValue( PdfName.BITSPERCOMPONENT ) );
						
						var img: Bytes = PdfReader.getStreamBytesRaw2( PRStream( stream ) );
						var loader: Loader = new Loader();
						loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onImageIOError );
						loader.contentLoaderInfo.addEventListener( Event.COMPLETE, onImageComplete );
						loader.loadBytes( img.buffer );

					}
				}

			}
		}
		
		private function onImageIOError( event: IOErrorEvent ): void
		{
			trace( event.text );
		}
		
		private function onImageComplete( event: Event ): void
		{
			addChild( ( event.target as LoaderInfo ).content );
		}
	}
}