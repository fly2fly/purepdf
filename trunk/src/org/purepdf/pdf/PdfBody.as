package org.purepdf.pdf
{
	import org.purepdf.utils.collections.TreeSet;
	import org.purepdf.utils.iterators.Iterator;

	/**
	 * This class generates the structure of a PDF document.
	 *
	 * @see		PdfWriter
	 * @see		PdfObject
	 * @see		PdfIndirectObject
	 */
	public class PdfBody
	{
		private static const OBJSINSTREAM: int = 200;
		private var currentObjNum: int;
		private var index: ByteBuffer;
		private var numObj: int = 0;
		private var position: int;
		private var refnum: int;
		private var streamObjects: ByteBuffer;
		private var writer: PdfWriter;
		private var xrefs: TreeSet;

		public function PdfBody( $writer: PdfWriter )
		{
			writer = $writer;
			xrefs = new TreeSet();
			xrefs.add( new PdfCrossReference( 0, 0, 0, PdfWriter.GENERATION_MAX ) );
			position = writer.getOs().getCounter();
			refnum = 1;
		}

		public function add( object: PdfObject, refNumber: int, inObjStm: Boolean=true ): PdfIndirectObject
		{
			var indirect: PdfIndirectObject;
			var pxref: PdfCrossReference;

			if ( inObjStm && object.canBeInObjStm() && writer.isFullCompression() )
			{
				pxref = addToObjStm( object, refNumber );
				indirect = new PdfIndirectObject( refNumber, 0, object, writer );

				if ( !xrefs.add( pxref ) )
				{
					xrefs.remove( pxref );
					xrefs.add( pxref );
				}
				return indirect;
			}
			else
			{
				indirect = new PdfIndirectObject( refNumber, 0, object, writer );
				pxref = new PdfCrossReference( 1, refNumber, position, 0 );

				if ( !xrefs.add( pxref ) )
				{
					xrefs.remove( pxref );
					xrefs.add( pxref );
				}
				indirect.writeTo( writer.getOs() );
				position = writer.getOs().getCounter();
				return indirect;
			}
		}

		public function add1( object: PdfObject ): PdfIndirectObject
		{
			return add( object, getIndirectReferenceNumber() );
		}

		public function add2( object: PdfObject, inObjStm: Boolean ): PdfIndirectObject
		{
			return add( object, getIndirectReferenceNumber(), inObjStm );
		}

		public function add3( object: PdfObject, ref: PdfIndirectReference ): PdfIndirectObject
		{
			return add4( object, ref.number );
		}

		public function add4( object: PdfObject, refNumber: int ): PdfIndirectObject
		{
			return add( object, refNumber, true ); // to false
		}

		public function add5( object: PdfObject, ref: PdfIndirectReference, inObjStm: Boolean ): PdfIndirectObject
		{
			return add( object, ref.number, inObjStm );
		}

		public function addToObjStm( obj: PdfObject, nObj: int ): PdfCrossReference
		{
			if ( numObj >= OBJSINSTREAM )
				flushObjStm();

			if ( index == null )
			{
				index = new ByteBuffer();
				streamObjects = new ByteBuffer();
				currentObjNum = getIndirectReferenceNumber();
				numObj = 0;
			}
			var p: int = streamObjects.size();
			var idx: int = numObj++;
			var enc: PdfEncryption = writer.getEncryption();
			writer.setEncryption( null );
			obj.toPdf( writer, streamObjects );
			writer.setEncryption( enc );
			streamObjects.append_char( ' ' );
			index.append( nObj ).append_char( ' ' ).append( p ).append_char( ' ' );
			return new PdfCrossReference( 2, nObj, currentObjNum, idx );
		}

		public function flushObjStm(): void
		{
			if ( numObj == 0 )
				return;
			var first: int = index.size();
			index.append_bytebuffer( streamObjects );
			var stream: PdfStream = new PdfStream( index.toByteArray() );
			stream.flateCompress( writer.getCompressionLevel() );
			stream.put( PdfName.TYPE, PdfName.OBJSTM );
			stream.put( PdfName.N, new PdfNumber( numObj ) );
			stream.put( PdfName.FIRST, new PdfNumber( first ) );
			add( stream, currentObjNum );
			index = null;
			streamObjects = null;
			numObj = 0;
		}

		public function getIndirectReferenceNumber(): int
		{
			var n: int = refnum++;
			xrefs.add( new PdfCrossReference( 0, n, 0, PdfWriter.GENERATION_MAX ) );
			return n;
		}

		/**
		 * Gets a PdfIndirectReference for an object that will be created in the future.
		 */
		public function getPdfIndirectReference(): PdfIndirectReference
		{
			return new PdfIndirectReference( 0, getIndirectReferenceNumber(), 0 );
		}

		public function offset(): int
		{
			return position;
		}

		public function setRefNum( value: int ): void
		{
			refnum = value;
		}

		/**
		 * Returns the total number of objects contained in the CrossReferenceTable of this <CODE>Body</CODE>.
		 */
		public function size(): int
		{
			return Math.max( ( xrefs.last() as PdfCrossReference ).getRefnum() + 1, refnum );
		}

		public function writeCrossReferenceTable( os: OutputStreamCounter, root: PdfIndirectReference, info: PdfIndirectReference, encryption: PdfIndirectReference, fileID: PdfObject, prevxref: int ): void
		{
			var refNumber: int = 0;

			if ( writer.isFullCompression() )
			{
				throw new Error( 'NonImplementationError' );
			}
			var i: Iterator;
			var entry: PdfCrossReference = PdfCrossReference( xrefs.first() );
			var first: int = entry.getRefnum();
			var len: int = 0;
			var sections: Vector.<int> = new Vector.<int>();
			i = xrefs.iterator();

			while ( i.hasNext() )
			{
				entry = PdfCrossReference( i.next() );

				if ( first + len == entry.getRefnum() )
				{
					++len;
				}
				else
				{
					sections.push( first );
					sections.push( len );
					first = entry.getRefnum();
					len = 1;
				}
			}
			sections.push( first );
			sections.push( len );

			if ( writer.isFullCompression() )
			{
				throw new Error( 'NonImplementationError' );
			}
			else
			{
				os.writeBytes( PdfWriter.getISOBytes( "xref\n" ) );
				i = xrefs.iterator();

				for ( var k: int = 0; k < sections.length; k += 2 )
				{
					first = sections[ k ];
					len = sections[ k + 1 ];
					os.writeBytes( PdfWriter.getISOBytes( first.toString() ) );
					os.writeBytes( PdfWriter.getISOBytes( " " ) );
					os.writeBytes( PdfWriter.getISOBytes( len.toString() ) );
					os.writeInt( '\n'.charCodeAt( 0 ) );

					while ( len-- > 0 )
					{
						entry = PdfCrossReference( i.next() );
						entry.toPdf( os );
					}
				}
			}
		}
	}
}